RSpec.describe Admin::UsagesController, type: :controller do
  render_views

  let(:user) { create(:user, authority: "admin") }

  before { sign_in user }

  describe "GET #index" do
    it "全ステータスの行を表示できること" do
      unconfirmed = create(:usage, status: :unconfirmed)
      approved = create(:usage, status: :approved)
      spam = create(:usage, status: :spam)
      get :index
      expect(response).to be_successful
      expect(assigns(:usages)).to include(unconfirmed, approved, spam)
    end

    context "status で絞り込むとき" do
      let!(:usage) { create(:usage) }
      let!(:spam_usage) { create(:usage, status: :spam) }

      it "指定した status のレコードのみ返すこと" do
        get :index, params: { status: "spam" }
        expect(assigns(:usages)).to include(spam_usage)
        expect(assigns(:usages)).to_not include(usage)
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
