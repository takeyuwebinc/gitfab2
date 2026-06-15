RSpec.describe Admin::ProjectCommentsController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe "GET #index" do
    subject { get :index }

    context "with authority" do
      let(:authority) { "admin" }
      it { is_expected.to be_successful }

      context "プロジェクト名リンク" do
        render_views

        let(:project) { create(:user_project) }
        let!(:project_comment) { create(:project_comment, project: project, status: :unconfirmed) }

        it "プロジェクト名リンクに project_id が含まれ絞り込みに使えること" do
          get :index, params: { status: "unconfirmed" }
          expect(response.body).to include("project_id=#{project.id}")
        end
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
