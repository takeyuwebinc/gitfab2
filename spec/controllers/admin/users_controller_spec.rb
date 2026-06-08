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

      it '操作者自身の行の剥奪ボタンを disabled で描画する' do
        subject
        doc = Nokogiri::HTML(response.body)
        self_form = doc.at_css("form[action='#{admin_user_admin_authority_path(user)}']")
        expect(self_form).to be_present
        expect(self_form.at_css('button, input[type=submit]')['disabled']).to be_present
      end

      it '他の管理者の行の剥奪ボタンは有効で描画する' do
        subject
        doc = Nokogiri::HTML(response.body)
        other_form = doc.at_css("form[action='#{admin_user_admin_authority_path(alice)}']")
        expect(other_form).to be_present
        expect(other_form.at_css('button, input[type=submit]')['disabled']).to be_nil
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
