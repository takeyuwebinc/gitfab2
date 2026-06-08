require 'spec_helper'

RSpec.describe Admin::Users::AdminAuthoritiesController, type: :controller do
  let(:operator) { create(:user, authority: authority) }

  before { sign_in operator }

  describe 'POST #create（付与）' do
    subject { post :create, params: { user_id: target.to_param } }

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

      context '対象が既に管理者の場合（冪等）' do
        let!(:target) { create(:administrator) }

        it '401 にならず成功扱いで一覧へリダイレクトする' do
          subject
          expect(response).to redirect_to(admin_users_path)
          expect(flash[:notice]).to be_present
        end
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
    subject { delete :destroy, params: { user_id: target.to_param } }

    context 'with authority' do
      let(:authority) { 'admin' }

      context '対象が存在しない場合' do
        subject { delete :destroy, params: { user_id: 'no-such-user' } }

        it 'RecordNotFound を発生させず、alert 付きで一覧へリダイレクトする' do
          expect { subject }.not_to raise_error
          expect(response).to redirect_to(admin_users_path)
          expect(flash[:alert]).to be_present
        end
      end

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

      context '対象が既に一般ユーザーの場合（冪等）' do
        let!(:other_admin) { create(:administrator) }
        let!(:target) { create(:user) }

        it '401 にならず成功扱いで一覧へリダイレクトする' do
          subject
          expect(response).to redirect_to(admin_users_path)
          expect(flash[:notice]).to be_present
        end
      end

      context '操作者自身を剥奪しようとした場合' do
        let(:target) { operator }

        it '認可で弾かれ 401 を返し、権限を変更しない' do
          expect { subject }.not_to change { operator.reload.is_system_admin? }
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context '最後の管理者を剥奪しようとした場合' do
        let!(:target) { operator }

        it '認可で弾かれ 401 を返し、権限を変更しない' do
          # operator が唯一の管理者のため、認可（自己剥奪の禁止）で弾かれる
          expect { subject }.not_to change { operator.reload.is_system_admin? }
          expect(response).to have_http_status(:unauthorized)
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
