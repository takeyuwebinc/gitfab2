RSpec.describe Admin::ProjectComments::SpamsController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { project_comment_id: project_comment.id } }
    let(:project_comment) { create(:project_comment) }

    context "with authority" do
      let(:authority) { "admin" }
      it "コメントをスパムにして一覧に戻すこと" do
        expect_any_instance_of(ProjectComment).to receive(:mark_spam!)
        is_expected.to redirect_to(admin_project_comments_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { project_comment_id: project_comment.id } }
    let(:project_comment) { create(:project_comment, :spam) }

    context "with authority" do
      let(:authority) { "admin" }
      it "スパムコメントの判定を取り消して一覧に戻すこと" do
        expect_any_instance_of(ProjectComment).to receive(:unmark_spam!)
        is_expected.to redirect_to(admin_project_comments_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
