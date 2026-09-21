# == Schema Information
#
# Table name: cards
#
#  id                                                  :integer          not null, primary key
#  comments_count                                      :integer          default(0), not null
#  description                                         :text(4294967295)
#  position                                            :integer          default(0), not null
#  status(確認ステータス 0:未確認 1:承認済み 2:スパム) :integer          default(0), not null
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

class Card::State < Card
  # 変換先として受け付けられない State を渡されたときに送出する。
  # 自身を渡すと state_id が自分の id を指す Annotation になり、STI のため所属 State を
  # 解決できず、プロジェクトのページからも一覧からも辿れなくなる。
  # 別プロジェクトの State を渡すと、カードが元のプロジェクトから移動してしまう。
  # どちらも書き込んだ後では元の position を復元できないため、書き込む前に拒否する。
  class InvalidConversionTarget < StandardError; end

  belongs_to :project, counter_cache: :states_count
  acts_as_list scope: [:project_id, type: Card::State.name]

  has_many :annotations, ->{ ordered_by_position },
                        class_name: 'Card::Annotation',
                        foreign_key: :state_id,
                        dependent: :destroy,
                        inverse_of: :state
  has_many :visible_annotations, ->{ not_spam.ordered_by_position },
                        class_name: 'Card::Annotation',
                        foreign_key: :state_id
  accepts_nested_attributes_for :annotations

  class << self
    def updatable_columns
      super + [:position, annotations_attributes: Card::Annotation.updatable_columns]
    end
  end

  # 変換は元の位置を失う。type が並びの scope に含まれるため、State でなくなった時点で
  # 同じプロジェクトの後続の State の position が 1 つずつ詰められ、自身の position も
  # Annotation の並びの値に書き換わる。State へ戻しても元の位置には戻らない。
  def to_annotation!(parent_state)
    raise InvalidConversionTarget if parent_state.id == id
    raise InvalidConversionTarget if parent_state.project_id != project_id

    transaction do
      update!(type: Card::Annotation.name, state_id: parent_state.id)
      project.decrement!(:states_count)
    end
    Card::Annotation.find(id)
  end

  def dup_document
    super.tap do |doc|
      doc.annotations = annotations.map(&:dup_document)
    end
  end
end

