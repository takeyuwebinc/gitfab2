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

    # Annotation は project_id 列を持たず、所属プロジェクトは state 経由で決まる。
    context "プロジェクト名リンク（project_id 列 nil・state 経由）" do
      let(:project) { create(:user_project) }
      let!(:annotation_in_project) { create(:annotation, state: create(:state, :without_annotations, project: project), status: :unconfirmed) }

      it "project_id 列が nil でもリンクに project_id が含まれ絞り込みに使えること" do
        expect(annotation_in_project.project_id).to be_nil
        get :index, params: { status: "unconfirmed" }
        expect(response.body).to include("project_id=#{project.id}")
      end
    end

    # state を解決できない孤児レコードが 1 件でもあると一覧全体が 500 になっていた。
    context "state を解決できない孤児 Annotation があるとき" do
      let!(:orphan) { create(:annotation, status: :unconfirmed).tap { |a| a.update_column(:state_id, nil) } }
      let!(:annotation) { create(:annotation, status: :unconfirmed) }

      it "孤児も含めて一覧を表示できること" do
        get :index
        expect(response).to be_successful
        expect(assigns(:annotations)).to include(orphan, annotation)
        expect(response.body).to include("所属プロジェクトなし")
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
