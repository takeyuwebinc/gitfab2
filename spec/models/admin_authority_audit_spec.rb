require 'spec_helper'

RSpec.describe AdminAuthorityAudit, type: :model do
  describe 'action enum' do
    it 'defines grant(付与) and revoke(剥奪)' do
      expect(described_class.actions).to eq('grant' => 0, 'revoke' => 1)
    end
  end

  describe '#audit_type_label' do
    it 'returns 管理者権限変更' do
      expect(build(:admin_authority_audit).audit_type_label).to eq '管理者権限変更'
    end
  end

  describe '#action_label' do
    it 'returns 付与 for grant' do
      expect(build(:admin_authority_audit, action: :grant).action_label).to eq '付与'
    end

    it 'returns 剥奪 for revoke' do
      expect(build(:admin_authority_audit, action: :revoke).action_label).to eq '剥奪'
    end
  end

  describe '#target_description' do
    it 'returns the target user name' do
      user = create(:user, name: 'target-user')
      audit = build(:admin_authority_audit, target_user: user)
      expect(audit.target_description).to eq 'target-user'
    end

    it 'falls back to the id when the target user is gone (loose reference)' do
      user = create(:user)
      audit = create(:audit_log, auditable: build(:admin_authority_audit, target_user: user)).auditable
      user.destroy!
      audit.reload
      expect(audit.target_user).to be_nil
      expect(audit.target_description).to eq "(削除済みユーザー ##{audit.target_user_id})"
    end
  end

  describe 'target_user association' do
    it 'points to the audited user' do
      user = create(:user)
      audit = create(:admin_authority_audit, target_user: user)
      expect(audit.target_user).to eq user
    end
  end

  describe '#operator' do
    it 'is delegated to the owning audit_log' do
      operator = create(:administrator)
      audit_log = create(:audit_log, operator: operator, auditable: build(:admin_authority_audit))
      audit = AdminAuthorityAudit.find(audit_log.auditable_id)
      expect(audit.operator).to eq operator
    end
  end

  describe 'AuditLog delegated_type integration' do
    it 'is registered as an auditable subtype' do
      audit_log = create(:audit_log, auditable: build(:admin_authority_audit))
      expect(audit_log.auditable).to be_a(AdminAuthorityAudit)
      expect(audit_log).to be_admin_authority_audit
    end
  end
end
