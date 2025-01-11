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

class CardComment < ApplicationRecord
  belongs_to :card, counter_cache: :comments_count
  belongs_to :user

  validates :body, presence: true

  scope :not_spam, -> { where(spam: false) }
end
