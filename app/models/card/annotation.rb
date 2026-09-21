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

class Card::Annotation < Card
  include SpamMarkable

  belongs_to :state, class_name: "Card::State", foreign_key: :state_id, inverse_of: :annotations
  # 並びの scope は state_id である。コールバックを通る更新で state_id を NULL にすると
  # scope の変更として扱われ、state_id が NULL のカード全体——すなわち全プロジェクトの
  # State——の position が振り直される。state_id を落とす必要があるときは、検証・
  # コールバック・タイムスタンプを通らない列単位の更新を使う。
  acts_as_list scope: :state

  scope :ordered_by_position, -> { order(:position) }
  # Annotation は project_id 列を持たず、所属プロジェクトは state 経由で決まる。
  scope :for_project, ->(project_id) { where(state_id: Card::State.where(project_id: project_id).select(:id)) }

  # 作成者は contributions のうち最古のレコードの contributor。
  # contribution が無いカードでは特定できないため nil を返す。
  def spam_author
    contributions.order(:created_at).first&.contributor
  end

  class << self
    def updatable_columns
      super + [:position]
    end
  end

  # state を解決できない孤児レコード（state_id が nil、または参照先が
  # Card::State でない）では所属プロジェクトを特定できないため nil を返す。
  def project
    state&.project
  end

  def to_state!(project)
    transaction do
      update!(
        type: Card::State.name,
        project_id: project.id,
        position: Card::State.where(project_id: project.id).maximum(:position).to_i + 1
      )
      project.increment!(:states_count)
    end

    Card::State.find(id)
  end
end
