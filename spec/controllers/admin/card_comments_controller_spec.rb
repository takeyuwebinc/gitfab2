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

      # コメントが付くカードが project_id 列を持たない型（Annotation 等、プロジェクトは
      # state 経由で決まる）でも、プロジェクト名リンクで絞り込め、絞り込み結果に含まれること。
      context "コメントが project_id 列を持たないカード（Annotation）に付くとき" do
        render_views

        let(:project) { create(:user_project) }
        let(:annotation_card) { create(:annotation, state: create(:state, :without_annotations, project: project)) }
        let!(:comment) { create(:card_comment, card: annotation_card, status: :unconfirmed) }

        it "前提として当該カードの project_id 列は nil であること" do
          expect(annotation_card.project_id).to be_nil
          expect(annotation_card.project.id).to eq project.id
        end

        it "プロジェクト名リンクに project_id が含まれ、絞り込みに使えること" do
          get :index, params: { status: "unconfirmed" }
          expect(response.body).to include("project_id=#{project.id}")
        end

        it "project_id で絞り込むと当該コメントが結果に含まれること（リンクと絞り込みが一致）" do
          get :index, params: { project_id: project.id, status: "unconfirmed" }
          expect(assigns(:card_comments)).to include(comment)
        end
      end
    end

    context "without authority" do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end
end
