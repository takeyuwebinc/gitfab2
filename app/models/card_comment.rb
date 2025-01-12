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
  include SpamCommentable
  belongs_to :card, counter_cache: :comments_count
  belongs_to :user

  validates :body, presence: true

  # コメントオブジェクトを作成する
  # 投稿者がスパム投稿者の場合、スパムコメントとして作成する
  def self.build_from(card, user, params)
    build(params).tap do |card_comment|
      card_comment.card = card
      card_comment.user = user
      card_comment.status = :spam if user.spammer?
    end
  end
end
