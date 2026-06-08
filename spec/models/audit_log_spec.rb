require 'spec_helper'

RSpec.describe AuditLog, type: :model do
  describe 'associations and delegated_type' do
    it 'belongs to an operator (User)' do
      operator = create(:administrator)
      audit_log = create(:audit_log, operator: operator)
      expect(audit_log.operator).to eq operator
    end

    it 'requires an operator' do
      expect(build(:audit_log, operator: nil)).not_to be_valid
    end

    it 'delegates the type detail to a subtype and exposes its predicate' do
      audit_log = create(:audit_log)
      expect(audit_log.auditable).to be_a(SpamModerationAudit)
      expect(audit_log).to be_spam_moderation_audit
    end

    it 'requires an auditable' do
      expect(build(:audit_log, auditable: nil)).not_to be_valid
    end
  end

  describe '.recent' do
    it 'orders by created_at descending' do
      older = create(:audit_log, created_at: 2.days.ago)
      newer = create(:audit_log, created_at: 1.day.ago)
      expect(AuditLog.recent.to_a).to eq [newer, older]
    end
  end
end
