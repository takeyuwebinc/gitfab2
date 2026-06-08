require 'spec_helper'

RSpec.describe Admin::Users::AdminAuthoritiesController, type: :controller do
  let(:operator) { create(:user, authority: authority) }

  before { sign_in operator }

  describe 'POST #create（付与）' do
    subject { post :create, params: { user_id: target.id } }

    let!(:target) { create(:user) }

    context 'with authority' do
      let(:authority) { 'admin' }

      it '対象に管理者権限を付与する' do
        expect { subject }.to change { target.reload.is_system_admin? }.from(false).to(true)
      end

      it 'notice 付きでユーザー一覧へリダイレクトする' do
        subject
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:notice]).to be_present
      end
    end

    context 'without authority' do
      let(:authority) { nil }

      it { is_expected.to redirect_to root_path }

      it '権限を変更しない' do
        expect { subject }.not_to change { target.reload.is_system_admin? }
      end
    end
  end

  describe 'DELETE #destroy（剥奪）' do
    subject { delete :destroy, params: { user_id: target.id } }

    context 'with authority' do
      let(:authority) { 'admin' }

      context '他に管理者が残る場合' do
        let!(:target) { create(:administrator) }

        it '対象の管理者権限を剥奪する' do
          expect { subject }.to change { target.reload.is_system_admin? }.from(true).to(false)
        end

        it 'notice 付きでリダイレクトする' do
          subject
          expect(response).to redirect_to(admin_users_path)
          expect(flash[:notice]).to be_present
        end
      end

      context '操作者自身を剥奪しようとした場合' do
        let(:target) { operator }

        it '権限を変更せず alert を表示する' do
          expect { subject }.not_to change { operator.reload.is_system_admin? }
          expect(flash[:alert]).to be_present
        end
      end

      context '最後の管理者を剥奪しようとした場合' do
        let!(:target) { operator }

        it '権限を変更せず alert を表示する' do
          # operator が唯一の管理者のため、自分自身の剥奪として拒否される
          expect { subject }.not_to change { operator.reload.is_system_admin? }
          expect(flash[:alert]).to be_present
        end
      end
    end

    context 'without authority' do
      let(:authority) { nil }
      let!(:target) { create(:administrator) }

      it { is_expected.to redirect_to root_path }

      it '権限を変更しない' do
        expect { subject }.not_to change { target.reload.is_system_admin? }
      end
    end
  end
end
