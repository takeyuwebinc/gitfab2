RSpec.describe Admin::AnnouncementsController, type: :controller do
  let(:authority) { raise "Define authority in each context" }
  before { sign_in create(:user, authority: authority) }

  describe 'GET #index' do
    let(:announcement) { create(:announcement) }
    context "with authority" do
      let(:authority) { "admin" }
      it 'returns a success response' do
        get :index
        expect(response).to be_successful
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #show' do
    let(:announcement) { create(:announcement) }
    context "with authority" do
      let(:authority) { "admin" }
      it 'returns a success response' do
        get :show, params: { id: announcement.to_param }
        expect(response).to be_successful
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        get :show, params: { id: announcement.to_param }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #new' do
    context "with authority" do
      let(:authority) { "admin" }
      it 'returns a success response' do
        get :new
        expect(response).to be_successful
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        get :new
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #edit' do
    let(:announcement) { create(:announcement) }
    context "with authority" do
      let(:authority) { "admin" }
      it 'returns a success response' do
        get :edit, params: { id: announcement.to_param }
        expect(response).to be_successful
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        get :edit, params: { id: announcement.to_param }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #create' do
    context "with authority" do
      let(:authority) { "admin" }
      context 'with valid params' do
        let(:valid_attributes) { attributes_for(:announcement) }

        it 'creates a new Announcement' do
          expect {
            post :create, params: { announcement: valid_attributes }
          }.to change(Announcement, :count).by(1)
        end

        it 'redirects to the announcements list' do
          post :create, params: { announcement: valid_attributes }
          expect(response).to redirect_to(admin_announcements_path)
        end
      end

      context 'with invalid params' do
        let(:invalid_attributes) { attributes_for(:announcement, title_ja: nil) }

        it 'does not create a new Announcement' do
          expect {
            post :create, params: { announcement: invalid_attributes }
          }.not_to change(Announcement, :count)
        end

        it 'renders the new template' do
          post :create, params: { announcement: invalid_attributes }
          expect(response).to render_template(:new)
        end
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        post :create, params: { announcement: attributes_for(:announcement) }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PUT #update' do
    let(:announcement) { create(:announcement) }
    context "with authority" do
      let(:authority) { "admin" }
      context 'with valid params' do
        let(:new_attributes) { { title_ja: 'New Title' } }

        it 'updates the requested announcement' do
          put :update, params: { id: announcement.to_param, announcement: new_attributes }
          announcement.reload
          expect(announcement.title_ja).to eq('New Title')
        end

        it 'redirects to the announcements list' do
          put :update, params: { id: announcement.to_param, announcement: new_attributes }
          expect(response).to redirect_to(admin_announcements_path)
        end
      end

      context 'with invalid params' do
        let(:invalid_attributes) { { title_ja: nil } }

        it 'does not update the announcement' do
          put :update, params: { id: announcement.to_param, announcement: invalid_attributes }
          announcement.reload
          expect(announcement.title_ja).not_to be_nil
        end

        it 'renders the edit template' do
          put :update, params: { id: announcement.to_param, announcement: invalid_attributes }
          expect(response).to render_template(:edit)
        end
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        put :update, params: { id: announcement.to_param, announcement: { title_ja: 'New Title' } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:announcement) { create(:announcement) }
    context "with authority" do
      let(:authority) { "admin" }
      it 'destroys the requested announcement' do
        expect {
          delete :destroy, params: { id: announcement.to_param }
        }.to change(Announcement, :count).by(-1)
      end

      it 'redirects to the announcements list' do
        delete :destroy, params: { id: announcement.to_param }
        expect(response).to redirect_to(admin_announcements_path)
      end
    end
    context "without authority" do
      let(:authority) { nil }
      it 'redirects to the root path' do
        delete :destroy, params: { id: announcement.to_param }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end