# == Schema Information
#
# Table name: cards
#
#  id                                                  :integer          not null, primary key
#  comments_count                                      :integer          default(0), not null
#  description                                         :text(4294967295)
#  position                                            :integer          default(0), not null
#  status(確認ステータス 0:未確認 1:承認済み 2:スパム) :integer          default("unconfirmed"), not null
#  title                                               :string(255)
#  type                                                :string(255)      not null
#  created_at                                          :datetime
#  updated_at                                          :datetime
#  project_id                                          :integer
#  state_id                                            :integer
#
# Indexes
#
#  index_cards_on_state_id  (state_id)
#  index_cards_project_id   (project_id)
#
# Foreign Keys
#
#  fk_cards_project_id  (project_id => projects.id)
#

class Card::Usage < Card
  include SpamMarkable

  belongs_to :project, counter_cache: :usages_count

  # 作成者は contributions のうち最古のレコードの contributor。
  # contribution が無いカードでは特定できないため nil を返す。
  def spam_author
    contributions.order(:created_at).first&.contributor
  end
end
