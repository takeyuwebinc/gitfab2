FactoryBot.define do
  factory :admin_authority_audit do
    action { :grant }
    association :target_user, factory: :user
  end
end
