# frozen_string_literal: true

describe GroupsController, type: :controller do
  render_views

  let(:user) { FactoryBot.create :user }
  let(:other) { FactoryBot.create :user }
  let(:group) { FactoryBot.create :group }

  subject { response }

  describe 'GET index' do
    subject { get :index }
    before { sign_in user }

    it { is_expected.to render_template :index }

    context 'when active and deleted groups' do
      let!(:active) { FactoryBot.create(:group, is_deleted: false) }
      let!(:deleted) { FactoryBot.create(:group, is_deleted: true) }
      before do
        user.memberships.create(group: active)
        user.memberships.create(group: deleted)
      end

      it 'fetches active groups only' do
        subject
        expect(assigns(:groups)).to eq [active]
      end
    end
  end

  describe 'GET new' do
    before do
      sign_in user
      get :new
    end
    it { is_expected.to render_template :new }
  end

  describe 'POST create' do
    before do
      sign_in user
      post :create, params: { group: group_params }
    end
    context 'with valid params' do
      let(:group_params) { FactoryBot.build(:group).attributes }
      it { is_expected.to redirect_to(edit_group_url(assigns(:group))) }
    end
    context 'with invalid params' do
      let(:group_params) { { name: nil } }
      it { is_expected.to render_template :new }
    end
  end

  describe 'GET edit' do
    subject { get :edit, params: { id: group } }

    describe 'as an admin' do
      before do
        user.memberships.create(group: group, role: 'admin')
        sign_in user
      end

      it { is_expected.to have_http_status :success }
      it { is_expected.to render_template :edit }
    end

    describe 'as an editor' do
      before do
        user.memberships.create(group: group, role: 'admin')
        sign_in other
        other.memberships.create(group: group, role: 'editor')
      end

      it { is_expected.to have_http_status :forbidden }
      it { is_expected.not_to render_template(layout: false) }
    end
  end

  describe 'PATCH update' do
    subject { patch :update, params: { id: group, group: group_params } }

    describe 'as an admin' do
      before do
        sign_in user
        user.memberships.create(group_id: group.id, role: 'admin')
      end

      context 'with valid params' do
        let(:group_params) { { name: 'updated' } }

        it { is_expected.to have_http_status :redirect }
        it 'updates a group' do
          expect { subject }.to change { group.reload.name }
        end
      end

      context 'with invalid params' do
        let(:group_params) { { name: nil } }

        it { is_expected.to have_http_status :success }
        it { is_expected.to render_template :edit }
        it 'does NOT update a group' do
          expect { subject }.not_to change { group.reload.name }
        end
      end
    end

    describe 'as an editor' do
      let(:group_params) { { name: 'updated' } }

      before do
        user.memberships.create(group: group, role: 'admin')
        sign_in other
        other.memberships.create(group: group, role: 'editor')
      end

      it 'does NOT update a group' do
        expect { subject }.not_to change { group.reload.name }
      end

      it { is_expected.to have_http_status :forbidden }
      it { is_expected.not_to render_template(layout: false) }
    end
  end

  describe 'DELETE destroy' do
    subject { delete :destroy, params: { id: group } }
    before { user.memberships.create(group_id: group.id, role: 'admin') }

    describe 'as an admin' do
      let!(:group) { FactoryBot.create :group }

      before { sign_in user }

      it { is_expected.to have_http_status :redirect }
      it { expect { subject }.to change { group.reload.is_deleted }.from(false).to(true) }
    end

    describe 'as an editor' do
      before do
        sign_in other
        other.memberships.create(group_id: group.id, role: 'editor')
      end

      it { is_expected.to have_http_status :forbidden }
      it { is_expected.not_to render_template(layout: false) }
      it { expect { subject }.not_to change { group.reload.is_deleted } }
    end

    describe 'projects' do
      before do
        sign_in user
        FactoryBot.create_list(:project, 2, owner: group, is_deleted: false)
      end

      it { is_expected.to redirect_to :groups }
      it 'deletes all projects' do
        subject
        expect(group.projects).to be_all { |p| p.is_deleted? }
      end
    end

    describe 'raise on soft_destroy!' do
      before do
        sign_in user
        FactoryBot.create_list(:project, 2, owner: group, is_deleted: false)
        allow_any_instance_of(Group).to receive(:soft_destroy!).and_raise(ActiveRecord::RecordNotSaved)
      end

      it { is_expected.to redirect_to edit_group_path(group) }
      it { expect { subject }.not_to change { group.is_deleted } }
      it { expect { subject }.not_to change { group.projects.count } }
    end
  end

  describe 'readonly mode restriction' do
    let(:group) { FactoryBot.create(:group) }

    before do
      sign_in user
      user.memberships.create(group: group, role: 'admin')
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      let(:group_params) { FactoryBot.build(:group).attributes }

      it 'does not create a group' do
        expect {
          post :create, params: { group: group_params }
        }.not_to change(Group, :count)
      end

      it 'redirects back with alert' do
        post :create, params: { group: group_params }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
      end
    end

    describe 'PATCH update' do
      it 'does not update the group' do
        patch :update, params: { id: group, group: { name: 'updated' } }
        expect(group.reload.name).not_to eq('updated')
      end

      it 'redirects back with alert' do
        patch :update, params: { id: group, group: { name: 'updated' } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
      end
    end

    describe 'DELETE destroy' do
      it 'does not delete the group' do
        expect {
          delete :destroy, params: { id: group }
        }.not_to change { group.reload.is_deleted }
      end

      it 'redirects back with alert' do
        delete :destroy, params: { id: group }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
      end
    end
  end
end
