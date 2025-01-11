# frozen_string_literal: true
# == Schema Information
#
# Table name: card_comments
#
#  id                             :integer          not null, primary key
#  body                           :text(65535)
#  spam(スパムコメントとして扱う) :boolean          default(FALSE), not null
#  created_at                     :datetime
#  updated_at                     :datetime
#  card_id                        :integer          not null
#  user_id                        :integer          not null
#
# Indexes
#
#  fk_rails_c8dff2752a     (card_id)
#  index_comments_user_id  (user_id)
#
# Foreign Keys
#
#  fk_comments_user_id  (user_id => users.id)
#  fk_rails_...         (card_id => cards.id)
#

FactoryBot.define do
  factory :card_comment do
    body { Faker::Lorem.sentence }
    association :user
    card
    spam { false }

    trait :spam do
      spam { true }
    end
  end
end
