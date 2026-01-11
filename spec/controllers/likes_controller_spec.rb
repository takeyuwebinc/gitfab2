RSpec.describe LikesController, type: :controller do

  describe "GET #show" do
    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(user) }
  
    context "when liked project" do
      before { Like.create!(project: project, user: user) }

      it "returns liked" do
        get :show, params: { owner_name: project.owner, project_id: project }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true, like: { liked: true } })
      end
    end

    context "when not liked project" do
      it "likes a project" do
        get :show, params: { owner_name: project.owner, project_id: project }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true, like: { liked: false } })
      end
    end
  end

  describe "POST #create" do
    subject { post :create, params: { owner_name: project.owner, project_id: project } }
    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(user) }

    context "when liked project" do
      before { Like.create!(project: project, user: user) }

      it "does not like a project" do
        expect{ subject }.not_to change{ Like.count }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
      end
    end

    context "when not liked project" do
      it "likes a project" do
        expect{ subject }.to change{ Like.count }.by(1)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
      end
    end

    context "on failed create" do
      before { sign_out }

      it "does not like a project" do
        expect{ subject }.not_to change{ Like.count }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: false })
      end
    end
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, params: { owner_name: project.owner, project_id: project } }
    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(user) }

    context "when liked project" do
      before { Like.create!(project: project, user: user) }

      it "unlikes a project" do
        expect{ subject }.to change{ Like.count }.by(-1)
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
      end
    end

    context "when not liked project" do
      it "does nothing" do
        expect{ subject }.not_to change{ Like.count }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
      end
    end
  end

  describe 'readonly mode restriction' do
    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before do
      sign_in(user)
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      it 'does not create a like' do
        expect {
          post :create, params: { owner_name: project.owner, project_id: project }, xhr: true
        }.not_to change(Like, :count)
      end

      it 'returns 503' do
        post :create, params: { owner_name: project.owner, project_id: project }, xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'DELETE destroy' do
      before { Like.create!(project: project, user: user) }

      it 'does not delete the like' do
        expect {
          delete :destroy, params: { owner_name: project.owner, project_id: project }, xhr: true
        }.not_to change(Like, :count)
      end

      it 'returns 503' do
        delete :destroy, params: { owner_name: project.owner, project_id: project }, xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

end
