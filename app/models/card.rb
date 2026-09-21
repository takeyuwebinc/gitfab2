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

class Card < ApplicationRecord
  include Figurable

  # 並べ替えの依頼が受け付けられない形のときに送出する。Hash でない組、id か position を
  # 持たない組、整数の表記でない position、同じ id を複数回含む依頼が該当する。
  class InvalidArrangement < StandardError; end

  ARRANGEMENT_POSITION_FORMAT = /\A-?\d+\z/

  has_many :attachments, as: :attachable, dependent: :destroy
  accepts_nested_attributes_for :attachments
  has_many :comments, class_name: "CardComment", dependent: :destroy
  has_many :visible_comments, -> { not_spam }, class_name: 'CardComment'
  has_many :contributions, dependent: :destroy
  has_many :contributors, through: :contributions, class_name: "User"

  # position の昇順に並べ、position が同じカードは id の昇順に並べる。MySQL は同じ position の
  # 行の順序を保証せず、実行計画しだいで画面ごとに並びが揺れるため、id で順序を確定させる。
  # rearrange! はこの順を「現在の表示順」として扱い、画面に出ないカードの置き場所を決める。
  # position の重複や欠番は一括では補正しない。表示の順はこの scope で確定し、position は
  # 並べ替えを確定したときに 1 からの連番へ振り直される。
  scope :ordered_by_position, -> { order(:position, :id) }

  validates :type, presence: true
  validate do
    if title.blank? && description.blank?
      errors.add(:base, "cannot make empty card.")
    end
  end

  def dup_document
    dup.tap do |card|
      card.figures = figures.map(&:dup_document)
      card.attachments = attachments.map(&:dup_document)
      card.comments_count = 0
      card.comments = []
    end
  end

  def htmlclass
    type.split(/::/).last.underscore
  end

  class << self
    def updatable_columns
      [:id, :title, :description, :type,
       figures_attributes: Figure.updatable_columns,
       attachments_attributes: Attachment.updatable_columns
      ]
    end

    def use_relative_model_naming?
      true
    end

    # 呼び出し元の relation を並べ替える範囲とし、依頼が要求する順に、範囲の全カードへ
    # 1 からの連番の position を振る。依頼は id と position の組の配列か、nested attributes と
    # 同じく index をキーにした Hash である。
    # - 依頼に含まれるカードは、要求された position の昇順に並べる。position が同じカードは
    #   現在の表示順（position、id の昇順）に従う。負の整数と 0 も並びのキーとして受け付ける
    # - 依頼に含まれないカードは、現在の表示順で直前にある「依頼に含まれるカード」の直後に置く。
    #   直前になければ先頭に置く。同じ場所に置くカードは現在の表示順を保つ
    # - position が変わるカードにだけ、position と updated_at を書き込む
    # 範囲に属さない id を含むと ActiveRecord::RecordNotFound を、依頼の形が不正なら
    # InvalidArrangement を送出し、どちらも何も書き込まない。
    def rearrange!(attributes_collection)
      requested = parse_arrangement(attributes_collection)
      # 範囲の行はロックしない。同じ範囲を同時に並べ替えると結果が混ざりうるが、画面が同時に送る
      # State と Annotation の並べ替えは書き込む行が重ならない。
      transaction do
        cards = unscope(:order).ordered_by_position.to_a
        ensure_arrangement_in_range!(cards.map(&:id), requested)

        # acts_as_list のコールバックは 1 件の移動を前提にしている。移動の前後の間にあるカードを
        # DB 上でずらすが、メモリ上のカードは更新しない。そのため 1 件ずつ保存すると、2 件目以降が
        # 古い position を基準にずらす範囲を誤り、並びが崩れて重複と欠番が残る。
        # 全カードの position をここで決め、コールバックと検証を通さずに書き込む。検証を通さないのは、
        # title と description が両方とも空のカードを含む範囲でも並べ替えを成り立たせるため。
        # updated_at を書き込むのは、position を表示に含むフラグメントキャッシュを作り直させるため。
        # updated_at は秒精度のため、同じ秒のうちに同じカードを並べ替え直すとキャッシュが古いまま残りうる。
        now = Time.current
        arranged_cards(cards, requested).each.with_index(1) do |card, position|
          card.update_columns(position: position, updated_at: now) unless card.position == position
        end
      end
    end

    # rearrange! と同じ規則で依頼を検証し、同じ例外を送出する。何も書き込まない。
    def verify_arrangement!(attributes_collection)
      requested = parse_arrangement(attributes_collection)
      ensure_arrangement_in_range!(where(id: requested.keys).pluck(:id), requested)
    end

    private

      # 依頼を id（文字列）から position（整数）への Hash にする。
      def parse_arrangement(attributes_collection)
        arrangement_entries(attributes_collection).each_with_object({}) do |attributes, requested|
          id = attributes[:id].to_s
          raise InvalidArrangement, 'id is missing' if id.empty?
          raise InvalidArrangement, "id #{id} is duplicated" if requested.key?(id)

          requested[id] = arrangement_position(attributes[:position])
        end
      end

      def arrangement_entries(attributes_collection)
        collection = attributes_collection.respond_to?(:permitted?) ? attributes_collection.to_h : attributes_collection
        collection = collection.values if collection.is_a?(Hash)
        Array(collection).map do |attributes|
          attributes = attributes.to_h if attributes.respond_to?(:permitted?)
          raise InvalidArrangement, "arrangement is not a hash: #{attributes.inspect}" unless attributes.is_a?(Hash)

          attributes.with_indifferent_access
        end
      end

      def arrangement_position(value)
        return value if value.is_a?(Integer)
        return value.to_i if value.is_a?(String) && value.match?(ARRANGEMENT_POSITION_FORMAT)

        raise InvalidArrangement, "position #{value.inspect} is not an integer"
      end

      def ensure_arrangement_in_range!(ids_in_range, requested)
        missing = requested.keys - ids_in_range.map(&:to_s)
        return if missing.empty?

        raise ActiveRecord::RecordNotFound.new(
          "Couldn't find #{name} with id #{missing.join(', ')} in the range to arrange", name, primary_key, missing
        )
      end

      # cards は現在の表示順に並んだ範囲の全カード。
      def arranged_cards(cards, requested)
        followers = Hash.new { |hash, id| hash[id] = [] }
        leader_id = nil
        cards.each do |card|
          if requested.key?(card.id.to_s)
            leader_id = card.id
          else
            followers[leader_id] << card
          end
        end

        current_index = cards.each_with_index.to_h { |card, index| [card.id, index] }
        leaders = cards.select { |card| requested.key?(card.id.to_s) }
                       .sort_by { |card| [requested[card.id.to_s], current_index[card.id]] }
        followers[nil] + leaders.flat_map { |card| [card, *followers[card.id]] }
      end
  end
end
