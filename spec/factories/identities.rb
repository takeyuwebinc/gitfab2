# == Schema Information
#
# Table name: identities
#
#  id         :bigint(8)        not null, primary key
#  email      :string(255)
#  image      :text(65535)
#  name       :string(255)
#  nickname   :string(255)
#  provider   :string(255)
#  uid        :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#
# Indexes
#
#  index_identities_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

# frozen_string_literal: true

FactoryBot.define do
  factory :identity do
    user
    provider { "github" }
    uid { "1234567" }
    email { "example@example.com" }
    name { "Tatsuya Itakura" }
    nickname { "itkrt2y" }
  end
end
