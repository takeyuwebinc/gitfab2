require 'spec_helper'

RSpec.describe SpamModerationAudit, type: :model do
  describe 'action enum' do
    it 'defines marked(記録) and unmarked(取消)' do
      expect(described_class.actions).to eq('marked' => 0, 'unmarked' => 1)
    end
  end

  describe '#action_label' do
    it 'returns 記録 for marked' do
      expect(build(:spam_moderation_audit, action: :marked).action_label).to eq '記録'
    end

    it 'returns 取消 for unmarked' do
      expect(build(:spam_moderation_audit, action: :unmarked).action_label).to eq '取消'
    end
  end

  describe 'target association' do
    it 'is polymorphic and points to the audited content' do
      comment = create(:project_comment)
      audit = create(:spam_moderation_audit, target: comment)
      expect(audit.target).to eq comment
      expect(audit.target_type).to eq 'ProjectComment'
    end

    it 'requires a target' do
      expect(build(:spam_moderation_audit, target: nil)).not_to be_valid
    end
  end

  describe '#operator' do
    it 'is delegated to the owning audit_log' do
      operator = create(:administrator)
      audit_log = create(:audit_log, operator: operator)
      audit = SpamModerationAudit.find(audit_log.auditable_id)
      expect(audit.operator).to eq operator
    end
  end
end
