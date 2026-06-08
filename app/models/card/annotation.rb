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
  acts_as_list scope: :state

  scope :ordered_by_position, -> { order(:position) }

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

  def project
    state.project
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
