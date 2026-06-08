RSpec.describe Admin::AnnotationsController, type: :controller do
  render_views

  let(:user) { create(:user, authority: "admin") }

  before { sign_in user }

  describe "GET #index" do
    it "全ステータスの行を表示できること" do
      unconfirmed = create(:annotation, status: :unconfirmed)
      approved = create(:annotation, status: :approved)
      spam = create(:annotation, status: :spam)
      get :index
      expect(response).to be_successful
      expect(assigns(:annotations)).to include(unconfirmed, approved, spam)
    end

    context "status で絞り込むとき" do
      let!(:annotation) { create(:annotation) }
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
