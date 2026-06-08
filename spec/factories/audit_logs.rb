FactoryBot.define do
  factory :audit_log do
    association :operator, factory: :administrator
    association :auditable, factory: :spam_moderation_audit
    ip_address { '198.51.100.7' }
  end
end
