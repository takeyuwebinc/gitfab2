RSpec.describe Admin::CardComments::SpamBatchesController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { before: time.to_param } }
    let!(:card_comment) { create(:card_comment, created_at: time) }
    let(:time) { 1.hour.ago }

    before do
      # 変更されない
      create(:card_comment, :approved, created_at: time - 1.second)
      create(:card_comment, :unconfirmed, created_at: time + 1.second)
    end

    context "with authority" do
      let(:authority) { "admin" }
      it "指定日時より古い未確認コメントをスパムにして一覧に戻すこと" do
        expect_any_instance_of(CardComment).to receive(:mark_spam!).exactly(1).times
        is_expected.to redirect_to(admin_card_comments_path)
      end

      context "status と page が指定されたとき" do
        subject { post :create, params: { before: time.to_param, status: "unconfirmed", page: "2" } }
        it "操作前のページ・絞り込みを維持して一覧に戻すこと" do
          allow_any_instance_of(CardComment).to receive(:mark_spam!)
          is_expected.to redirect_to(admin_card_comments_path(status: "unconfirmed", page: "2"))
        end
      end

    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "POST #create プロジェクト単位の絞り込み安全性" do
    let(:user) { create(:user, authority: "admin") }
    let(:time) { 1.hour.ago }
    let(:project) { create(:user_project) }
    let(:other_project) { create(:user_project) }

    before { sign_in user }

    # 当該プロジェクト・未確認・before 以前（スパム化の対象）
    let!(:target_before) { mk(project, :unconfirmed, time - 1.second) }
    let!(:target_at)     { mk(project, :unconfirmed, time) }
    # 当該プロジェクト・対象外（before より新しい / 承認済み）
    let!(:in_newer)      { mk(project, :unconfirmed, time + 1.second) }
    let!(:in_approved)   { mk(project, :approved,    time - 1.second) }
    # フィルタ外プロジェクト・未確認・before 以前（漏れたら事故。不変であること）
    let!(:out_before)    { mk(other_project, :unconfirmed, time - 1.second) }
    let!(:out_at)        { mk(other_project, :unconfirmed, time) }

    context "project_id を指定したとき" do
      subject { post :create, params: { before: time.to_param, project_id: project.id } }

      it "当該プロジェクトの未確認(before以前)のみスパム化すること" do
        subject
        expect(target_before.reload).to be_spam
        expect(target_at.reload).to be_spam
      end

      it "フィルタ外プロジェクトの未確認は一切スパム化しないこと" do
        subject
        expect(out_before.reload).to be_unconfirmed
        expect(out_at.reload).to be_unconfirmed
      end

      it "当該プロジェクトでも before より新しい・承認済みは対象外であること" do
        subject
        expect(in_newer.reload).to be_unconfirmed
        expect(in_approved.reload).to be_approved
      end

      it "スパム化されるのは対象2件だけで他へ波及しないこと" do
        expect { subject }.to change { CardComment.spam.count }.from(0).to(2)
      end
    end

    context "コメントが Annotation カード（project_id 列 nil・state 経由）に付くとき" do
      let!(:anno_in) do
        create(:card_comment,
               card: create(:annotation, state: create(:state, :without_annotations, project: project)),
               status: :unconfirmed, created_at: time - 1.second)
      end
      let!(:anno_out) do
        create(:card_comment,
               card: create(:annotation, state: create(:state, :without_annotations, project: other_project)),
               status: :unconfirmed, created_at: time - 1.second)
      end

      subject { post :create, params: { before: time.to_param, project_id: project.id } }

      it "当該プロジェクトの Annotation カード上の未確認もスパム化すること" do
        subject
        expect(anno_in.reload).to be_spam
      end

      it "別プロジェクトの Annotation カード上の未確認は一切スパム化しないこと" do
        subject
        expect(anno_out.reload).to be_unconfirmed
      end
    end

    context "project_id を指定しないとき（フィルタが効いている対照）" do
      subject { post :create, params: { before: time.to_param } }

      it "フィルタ外プロジェクトの未確認(before以前)も対象になること" do
        subject
        expect(out_before.reload).to be_spam
        expect(out_at.reload).to be_spam
      end
    end

    def mk(project, status, created_at)
      create(:card_comment, card: create(:note_card, project: project), status: status, created_at: created_at)
    end
  end
end
