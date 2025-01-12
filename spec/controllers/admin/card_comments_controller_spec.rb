RSpec.describe Admin::CardCommentsController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe "GET #index" do
    subject { get :index }

    context "with authority" do
      let(:authority) { "admin" }
      it { is_expected.to be_successful }
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
