RSpec.describe Admin::CardCommentsController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe "GET #index" do
    subject { get :index }

    context "with authority" do
      let(:authority) { "admin" }
      it { is_expected.to be_successful }

      context "project_id が指定されたとき" do
        subject { get :index, params: { project_id: project.id } }
        let(:project) { create(:user_project) }
        let!(:target) { create(:card_comment, card: create(:note_card, project: project)) }
        let!(:other) { create(:card_comment, card: create(:note_card)) }

        it "当該プロジェクトのコメントのみを表示すること" do
          subject
          expect(assigns(:card_comments)).to contain_exactly(target)
          expect(assigns(:project)).to eq project
        end
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
