RSpec.describe Admin::TagsController, type: :controller do
  render_views

  let(:user) { create(:user, authority: "admin") }

  before { sign_in user }

  describe "GET #index" do
    it "全ステータスの行を表示できること" do
      unconfirmed = create(:tag, status: :unconfirmed)
      approved = create(:tag, status: :approved)
      spam = create(:tag, status: :spam)
      get :index
      expect(response).to be_successful
      expect(assigns(:tags)).to include(unconfirmed, approved, spam)
    end

    context "status で絞り込むとき" do
      let!(:tag) { create(:tag) }
      let!(:spam_tag) { create(:tag, status: :spam) }

      it "指定した status のレコードのみ返すこと" do
        get :index, params: { status: "spam" }
        expect(assigns(:tags)).to include(spam_tag)
        expect(assigns(:tags)).to_not include(tag)
      end
    end

    context "プロジェクト名リンク" do
      let(:project) { create(:user_project) }
      let!(:tag_in_project) { create(:tag, project: project, status: :unconfirmed) }

      it "プロジェクト名リンクに project_id が含まれ絞り込みに使えること" do
        get :index, params: { status: "unconfirmed" }
        expect(response.body).to include("project_id=#{project.id}")
      end
    end

    context "without authority" do
      let(:user) { create(:user) }

      it "root に戻すこと" do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
