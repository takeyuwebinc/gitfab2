RSpec.describe Admin::Annotations::SpamsController, type: :controller do
  let(:user) { create(:user, authority:) }

  before { sign_in user }

  describe "POST #create" do
    subject { post :create, params: { annotation_id: annotation.id } }
    let(:annotation) { create(:annotation) }

    context "with authority" do
      let(:authority) { "admin" }
      it "スパムにして一覧に戻すこと" do
        expect_any_instance_of(Card::Annotation).to receive(:mark_spam!)
        is_expected.to redirect_to(admin_annotations_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { annotation_id: annotation.id } }
    let(:annotation) { create(:annotation, status: :spam) }

    context "with authority" do
      let(:authority) { "admin" }
      it "スパム判定を取り消して一覧に戻すこと" do
        expect_any_instance_of(Card::Annotation).to receive(:unmark_spam!)
        is_expected.to redirect_to(admin_annotations_path)
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
