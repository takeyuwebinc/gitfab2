require 'spec_helper'

RSpec.describe Admin::AuditLogsController, type: :controller do
  let(:authority) { 'admin' }
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe 'GET #index' do
    render_views

    subject { get :index }

    let!(:older) { create(:audit_log, auditable: build(:spam_moderation_audit, action: :marked), created_at: 2.days.ago) }
    let!(:newer) { create(:audit_log, auditable: build(:spam_moderation_audit, action: :unmarked), created_at: 1.day.ago) }

    context 'with authority' do
      let(:authority) { 'admin' }

      it { is_expected.to be_successful }

      it '操作者・操作種別・対象種別を表示する' do
        subject
        expect(response.body).to include('スパム認定')
        expect(response.body).to include('記録')
        expect(response.body).to include('取消')
        expect(response.body).to include('ProjectComment')
      end

      it '新しい順で並べる' do
        subject
        expect(assigns(:audit_logs).to_a).to eq [newer, older]
      end
    end

    context 'without authority' do
      let(:authority) { nil }

      it { is_expected.to redirect_to root_path }
    end
  end

  describe '読み取り専用（作成/更新/削除のルートを持たない）' do
    it 'index 以外の操作はルーティングされない' do
      expect(post: '/admin/audit_logs').not_to be_routable
      expect(put: '/admin/audit_logs/1').not_to be_routable
      expect(patch: '/admin/audit_logs/1').not_to be_routable
      expect(delete: '/admin/audit_logs/1').not_to be_routable
    end
  end
end
