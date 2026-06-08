FactoryBot.define do
  factory :audit_log do
    association :operator, factory: :administrator
    association :auditable, factory: :spam_moderation_audit
  end
end
