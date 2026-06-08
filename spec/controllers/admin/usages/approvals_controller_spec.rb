RSpec.describe Admin::Usages::ApprovalsController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { usage_id: usage.id } }
    let(:usage) { create(:usage) }

    context "with authority" do
      let(:authority) { "admin" }
      it "承認して一覧に戻すこと" do
        expect_any_instance_of(Card::Usage).to receive(:approve!)
        is_expected.to redirect_to(admin_usages_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { usage_id: usage.id } }
    let(:usage) { create(:usage, status: :approved) }

    context "with authority" do
      let(:authority) { "admin" }
      it "承認を取り消して一覧に戻すこと" do
        expect_any_instance_of(Card::Usage).to receive(:unapprove!)
        is_expected.to redirect_to(admin_usages_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
