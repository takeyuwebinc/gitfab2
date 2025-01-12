# == Schema Information
#
# Table name: projects
#
#  id                        :integer          not null, primary key
#  description               :text(65535)
#  draft                     :text(65535)
#  is_deleted                :boolean          default(FALSE), not null
#  is_private                :boolean          default(FALSE), not null
#  license                   :integer          not null
#  likes_count               :integer          default(0), not null
#  name                      :string(255)      not null
#  note_cards_count          :integer          default(0), not null
#  owner_type                :string(255)      not null
#  project_access_logs_count :integer          default(0), not null
#  scope                     :string(255)
#  slug                      :string(255)
#  states_count              :integer          default(0), not null
#  title                     :string(255)      not null
#  usages_count              :integer          default(0), not null
#  created_at                :datetime
#  updated_at                :datetime
#  original_id               :integer
#  owner_id                  :integer          not null
#
# Indexes
#
#  index_projects_on_is_private_and_is_deleted  (is_private,is_deleted)
#  index_projects_original_id                   (original_id)
#  index_projects_owner                         (owner_type,owner_id)
#  index_projects_slug_owner                    (slug,owner_type,owner_id) UNIQUE
#  index_projects_updated_at                    (updated_at)
#

class Project < ApplicationRecord
  include Figurable
  include Notificatable

  extend FriendlyId
  friendly_id :name, use: %i(slugged scoped), scope: :owner_id

  belongs_to :original, class_name: 'Project', inverse_of: :derivatives, optional: true
  belongs_to :owner, polymorphic: true
  has_many :collaborations
  has_many :derivatives, class_name: 'Project', foreign_key: :original_id, inverse_of: :original
  has_many :likes, dependent: :destroy
  has_many :note_cards, class_name: 'Card::NoteCard', dependent: :destroy
  has_many :states, class_name: 'Card::State', dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :usages, class_name: 'Card::Usage', dependent: :destroy
  has_many :project_comments, dependent: :destroy
  has_many :visible_project_comments, -> { not_spam }, class_name: 'ProjectComment'
  has_many :project_access_logs, dependent: :destroy
  has_many :project_access_statistics, dependent: :destroy

  enum :license, { 'by' => 0, 'by-sa' => 1, 'by-nc' => 2, 'by-nc-sa' => 3 }

  before_save :set_draft

  after_initialize -> { self.license ||= 'by' }

  after_commit -> { owner.update_projects_count }

  validates :name, presence: true, name_format: true
  validates :name, uniqueness: { scope: [:owner_id, :owner_type], case_sensitive: false }
  validates :title, presence: true
  validates :license, presence: true

  scope :active, -> { where(is_deleted: false) }
  scope :exclude_blacklisted, -> { where.not(id: BlackList.select(:project_id)) }
  scope :noted, -> { joins(:note_cards).where.not(cards: { id: nil }) }
  scope :ordered_by_owner, -> { order(:owner_id) }
  scope :published, -> { active.where(is_private: false) }

  # draft全文検索
  scope :search_draft, -> (text) do
    projects = all
    text.split(/\p{space}+/).each do |word|
      projects = projects.where("#{table_name}.draft LIKE ?", "%#{word}%")
    end
    projects
  end

  scope :access_ranking, -> (from: 1.month.ago, to: Time.current, limit: 10) do
    published
      .joins(:project_access_logs)
      .where("project_access_logs.created_at BETWEEN :from AND :to", from: from, to: to)
      .exclude_blacklisted
      .group(:id)
      .select('projects.*, COUNT(projects.id) as access_count')
      .order(Arel.sql("access_count DESC"))
      .limit(limit)
  end

  accepts_nested_attributes_for :states
  accepts_nested_attributes_for :usages

  paginates_per 12

  def self.find_with(owner_slug, project_slug)
    Owner.find(owner_slug).projects.active.friendly.find(project_slug)
  end

  # このプロジェクトを owner のプロジェクトとしてフォークする
  def fork_for!(owner)
    dup.tap do |project|
      project.owner = owner
      project.original = self
      names = owner.projects.pluck :name
      new_project_name = name.dup
      if names.include? new_project_name
        new_project_name << '-1'
        new_project_name.sub!(/(\d+)$/, "#{Regexp.last_match(1).to_i + 1}") while names.include? new_project_name
      end
      project.name = new_project_name
      project.states_count = 0
      project.states = states.map(&:dup_document)
      project.figures = figures.map(&:dup_document)
      project.likes_count = 0
      project.likes = []
      project.usages_count = 0
      project.usages = []
      project.note_cards_count = 0

      project.save!
    end
  end

  def managers
    owner.is_a?(User) ? [owner] : owner.members
  end

  def collaborate_users
    collaborators.map do |collaborator|
      collaborator.is_a?(User) ? collaborator : collaborator.members
    end.flatten
  end

  def root
    original&.root || self
  end

  def is_fork?
    !!original_id
  end

  def collaborators
    collaborations.map(&:owner)
  end

  def soft_destroy
    update(is_deleted: true)
  end

  def soft_destroy!
    transaction do
      update!(title: 'Deleted Project', name: "deleted-project-#{SecureRandom.uuid}", is_deleted: true)
      likes.destroy_all
      states.destroy_all
      note_cards.destroy_all
      usages.destroy_all
      project_comments.destroy_all
      figures.destroy_all
      tags.destroy_all
      collaborations.destroy_all
    end
  end

  def update_draft!
    update!(draft: generate_draft)
  end

  def manageable_by?(user)
    !is_deleted && user.is_project_manager?(self)
  end

  class << self
    def updatable_columns
      [:name, :title, :description, :owner_type, :is_private, :is_deleted, :license,
       figures_attributes: Figure.updatable_columns
      ]
    end
  end

  private

    def generate_draft
      lines = [name, title, description, owner.generate_draft]
      states.each do |state|
        lines << ActionController::Base.helpers.strip_tags(state.description)
      end
      tags.each do |t|
        lines << t.generate_draft
      end
      lines.join("\n")
    end

    def set_draft
      self.draft = generate_draft
    end

    def should_generate_new_friendly_id?
      name_changed? || super
    end
end
