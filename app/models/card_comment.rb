# == Schema Information
#
# Table name: card_comments
#
#  id                                                  :integer          not null, primary key
#  body                                                :text(65535)
#  status(確認ステータス 0:未確認 1:承認済み 2:スパム) :integer          default("unconfirmed"), not null
#  created_at                                          :datetime
#  updated_at                                          :datetime
#  card_id                                             :integer          not null
#  user_id                                             :integer          not null
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

  enum :status, { unconfirmed: 0, approved: 1, spam: 2 }
end
