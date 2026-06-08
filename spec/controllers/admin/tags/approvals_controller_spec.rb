RSpec.describe Admin::Tags::ApprovalsController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { tag_id: tag.id } }
    let(:tag) { create(:tag) }

    context "with authority" do
      let(:authority) { "admin" }
      it "承認して一覧に戻すこと" do
        expect_any_instance_of(Tag).to receive(:approve!)
        is_expected.to redirect_to(admin_tags_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { tag_id: tag.id } }
    let(:tag) { create(:tag, status: :approved) }

    context "with authority" do
      let(:authority) { "admin" }
      it "承認を取り消して一覧に戻すこと" do
        expect_any_instance_of(Tag).to receive(:unapprove!)
        is_expected.to redirect_to(admin_tags_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
