RSpec.describe Admin::Annotations::SpamBatchesController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { before: time.to_param } }
    let!(:annotation) { create(:annotation, created_at: time) }
    let(:time) { 1.hour.ago }

    before do
      # 変更されない
      create(:annotation, status: :approved, created_at: time - 1.second)
      create(:annotation, status: :unconfirmed, created_at: time + 1.second)
    end

    context "with authority" do
      let(:authority) { "admin" }
      it "指定日時より古い未確認をスパムにして一覧に戻すこと" do
        expect_any_instance_of(Card::Annotation).to receive(:mark_spam!).exactly(1).times
        is_expected.to redirect_to(admin_annotations_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  # Annotation は project_id 列を持たず、所属プロジェクトは state 経由で決まる。
  # state 経由の絞り込みが正しく機能し、フィルタ外へ波及しないことを検証する。
  describe "POST #create プロジェクト単位の絞り込み安全性" do
    let(:user) { create(:user, authority: "admin") }
    let(:time) { 1.hour.ago }
    let(:project) { create(:user_project) }
    let(:other_project) { create(:user_project) }

    before { sign_in user }

    let!(:target_before) { mk(project, :unconfirmed, time - 1.second) }
    let!(:target_at)     { mk(project, :unconfirmed, time) }
    let!(:in_newer)      { mk(project, :unconfirmed, time + 1.second) }
    let!(:in_approved)   { mk(project, :approved,    time - 1.second) }
    let!(:out_before)    { mk(other_project, :unconfirmed, time - 1.second) }
    let!(:out_at)        { mk(other_project, :unconfirmed, time) }

    context "project_id を指定したとき" do
      subject { post :create, params: { before: time.to_param, project_id: project.id } }

      it "target は project_id 列を持たない（state 経由でのみプロジェクトに紐づく）こと" do
        expect(target_before.project_id).to be_nil
        expect(target_before.state.project_id).to eq project.id
      end

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
        expect { subject }.to change { Card::Annotation.spam.count }.from(0).to(2)
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
      create(:annotation, state: create(:state, :without_annotations, project: project), status: status, created_at: created_at)
    end
  end
end
