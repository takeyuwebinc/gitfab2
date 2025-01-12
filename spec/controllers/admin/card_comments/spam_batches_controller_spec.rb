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
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
