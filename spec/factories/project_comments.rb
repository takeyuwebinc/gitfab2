# == Schema Information
#
# Table name: project_comments
#
#  id                                                  :bigint(8)        not null, primary key
#  body                                                :text(65535)      not null
#  status(確認ステータス 0:未確認 1:承認済み 2:スパム) :integer          default("unconfirmed"), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  project_id                                          :integer          not null
#  user_id                                             :integer          not null
#
# Indexes
#
#  index_project_comments_on_project_id  (project_id)
#  index_project_comments_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#

FactoryBot.define do
  factory :project_comment do
    body { Faker::Lorem.sentence }
    user
    project

    trait :spam do
      status { "spam" }
    end

    trait :approved do
      status { "approved" }
    end
  end
end
