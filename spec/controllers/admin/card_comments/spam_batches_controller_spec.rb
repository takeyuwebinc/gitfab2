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

      context "project_id が指定されたとき" do
        subject { post :create, params: { before: time.to_param, project_id: project.id } }
        let(:project) { create(:user_project) }
        let!(:in_project) { create(:card_comment, card: create(:note_card, project: project), created_at: time) }
        let!(:out_project) { create(:card_comment, card: create(:note_card), created_at: time) }

        it "当該プロジェクトの未確認のみスパムにすること" do
          subject
          expect(in_project.reload).to be_spam
          expect(out_project.reload).to be_unconfirmed
        end
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
