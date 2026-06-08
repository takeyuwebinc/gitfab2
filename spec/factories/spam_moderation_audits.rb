FactoryBot.define do
  factory :spam_moderation_audit do
    action { :marked }
    association :target, factory: :project_comment
  end
end
