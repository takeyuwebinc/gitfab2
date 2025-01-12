RSpec.describe Admin::CardComments::SpamsController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { card_comment_id: card_comment.id } }
    let(:card_comment) { create(:card_comment) }

    context "with authority" do
      let(:authority) { "admin" }
      it "コメントをスパムにして一覧に戻すこと" do
        expect_any_instance_of(CardComment).to receive(:mark_spam!)
        is_expected.to redirect_to(admin_card_comments_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { card_comment_id: card_comment.id } }
    let(:card_comment) { create(:card_comment, :spam) }

    context "with authority" do
      let(:authority) { "admin" }
      it "スパムコメントの判定を取り消して一覧に戻すこと" do
        expect_any_instance_of(CardComment).to receive(:unmark_spam!)
        is_expected.to redirect_to(admin_card_comments_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
