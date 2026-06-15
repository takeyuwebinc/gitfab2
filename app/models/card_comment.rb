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
  include SpamMarkable
  belongs_to :card, counter_cache: :comments_count
  belongs_to :user

  # コメントが付くカードの所属プロジェクトで絞り込む。カードの所属プロジェクトは
  # project_id 列で直接持つ場合（NoteCard 等）と、project_id 列を持たず state 経由で
  # 決まる場合（Annotation）がある。両経路を網羅し、表示・リンクの card.project と
  # 一致させる。
  scope :for_project, ->(project_id) {
    cards_in_project = Card.where(project_id: project_id)
                          .or(Card.where(state_id: Card::State.where(project_id: project_id).select(:id)))
    where(card_id: cards_in_project.select(:id))
  }

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
