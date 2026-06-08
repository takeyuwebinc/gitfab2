RSpec.describe Admin::AnnotationsController, type: :controller do
  render_views

  let(:user) { create(:user, authority: "admin") }

  before { sign_in user }

  describe "GET #index" do
    let!(:annotation) { create(:annotation) }

    it "一覧を表示すること" do
      get :index
      expect(response).to be_successful
      expect(assigns(:annotations)).to include(annotation)
    end

    context "status で絞り込むとき" do
      let!(:spam_annotation) { create(:annotation, status: :spam) }

      it "指定した status のレコードのみ返すこと" do
        get :index, params: { status: "spam" }
        expect(assigns(:annotations)).to include(spam_annotation)
        expect(assigns(:annotations)).to_not include(annotation)
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
