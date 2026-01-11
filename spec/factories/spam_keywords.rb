FactoryBot.define do
  factory :spam_keyword do
    sequence(:keyword) { |n| "spam_keyword_#{n}" }
    enabled { true }
  end
end
