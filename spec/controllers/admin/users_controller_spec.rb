require 'spec_helper'

RSpec.describe Admin::UsersController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe 'GET #index' do
    render_views

    subject { get :index, params: params }
    let(:params) { {} }

    context 'with authority' do
      let(:authority) { 'admin' }

      let!(:alice) { create(:administrator, name: 'alice', email: 'alice@example.com') }
      let!(:bob) { create(:user, name: 'bob', email: 'bob@example.com') }

      it { is_expected.to be_successful }

      it '管理者権限の有無を表示する' do
        subject
        expect(response.body).to include('alice')
        expect(response.body).to include('bob')
      end

      context 'ユーザー名で検索した場合' do
        let(:params) { { q: 'alice' } }

        it '一致するユーザーのみ返す' do
          subject
          expect(assigns(:users)).to include(alice)
          expect(assigns(:users)).not_to include(bob)
        end
      end

      context 'メールアドレスで検索した場合' do
        let(:params) { { q: 'bob@example' } }

        it '一致するユーザーのみ返す' do
          subject
          expect(assigns(:users)).to include(bob)
          expect(assigns(:users)).not_to include(alice)
        end
      end
    end

    context 'without authority' do
      let(:authority) { nil }

      it { is_expected.to redirect_to root_path }
    end
  end
end
