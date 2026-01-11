# frozen_string_literal: true

describe MembersController, type: :controller do

  describe 'POST create' do
    subject { post :create, params: { group_id: group.id, member_name: user.to_param }, xhr: true }

    context 'when an administrator is signed in' do
      let(:group) { FactoryBot.create :group }
      let(:user) { FactoryBot.create :user }

      before do
        current_user = FactoryBot.create(:user)
        sign_in(current_user)

        FactoryBot.create(:membership, group: group, user: current_user, role: "admin")
      end
  
      it { is_expected.to have_http_status(:ok) }
      it { is_expected.to render_template :create }
      it { expect { subject }.to change(user.memberships, :count).by(1) }
    end

    context 'when an editor is signed in' do
      let(:group) { FactoryBot.create :group }
      let(:user) { FactoryBot.create :user }

      before do
        current_user = FactoryBot.create(:user)
        sign_in(current_user)

        FactoryBot.create(:membership, group: group, user: current_user, role: "editor")
      end
  
      it { is_expected.to_not have_http_status(:ok) }
      it { expect { subject }.to_not change(user.memberships, :count) }
    end

    context 'when not a member is signed in' do
      let(:group) { FactoryBot.create :group }
      let(:user) { FactoryBot.create :user }

      before do
        current_user = FactoryBot.create(:user) 
        sign_in(current_user)
      end
  
      it { is_expected.to_not have_http_status(:ok) }
      it { expect { subject }.to_not change(user.memberships, :count) }
    end

    context 'when an anonymous' do
      let(:group) { FactoryBot.create :group }
      let(:user) { FactoryBot.create :user }

      it { is_expected.to_not have_http_status(:ok) }
      it { expect { subject }.to_not change(user.memberships, :count) }
    end
  end

  describe 'readonly mode restriction' do
    let(:group) { FactoryBot.create :group }
    let(:user) { FactoryBot.create :user }
    let(:admin_user) { FactoryBot.create :user }

    before do
      sign_in admin_user
      FactoryBot.create(:membership, group: group, user: admin_user, role: "admin")
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      it 'does not add a member' do
        expect {
          post :create, params: { group_id: group.id, member_name: user.to_param }, xhr: true
        }.not_to change(Membership, :count)
      end

      it 'returns 503' do
        post :create, params: { group_id: group.id, member_name: user.to_param }, xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
