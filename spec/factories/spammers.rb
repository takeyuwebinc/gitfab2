# == Schema Information
#
# Table name: spammers
#
#  id                                      :bigint(8)        not null, primary key
#  detected_at(スパムとして検知された日時) :datetime
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  user_id                                 :integer          not null
#
# Indexes
#
#  index_spammers_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :spammer do
    user
    detected_at { Time.current }
  end
end
