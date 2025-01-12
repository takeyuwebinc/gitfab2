RSpec.describe Admin::SpammersController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe "GET #index" do
    subject { get :index }
    before do
      create_list(:spammer, 3)
    end

    context "with authority" do
      let(:authority) { "admin" }
      it { is_expected.to be_successful }
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { id: spammer.id } }
    let!(:spammer) { create(:spammer) }

    context "with authority" do
      let(:authority) { "admin" }

      it do
        expect { subject }.to change(Spammer, :count).by(-1)
        is_expected.to redirect_to admin_spammers_path
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
