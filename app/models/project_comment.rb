# == Schema Information
#
# Table name: project_comments
#
#  id                                                  :bigint(8)        not null, primary key
#  body                                                :text(65535)      not null
#  status(確認ステータス 0:未確認 1:承認済み 2:スパム) :integer          default("unconfirmed"), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  project_id                                          :integer          not null
#  user_id                                             :integer          not null
#
# Indexes
#
#  index_project_comments_on_project_id  (project_id)
#  index_project_comments_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#

class ProjectComment < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :body, presence: true, length: { maximum: 300 }

  enum :status, { unconfirmed: 0, approved: 1, spam: 2 }

  def manageable_by?(user)
    self.user == user || project.manageable_by?(user)
  end

  # コメントを承認する
  def approve!
    update!(status: :approved)
  end

  # コメントの承認を解除する
  def unapprove!
    return if unconfirmed?
    raise "Can't unapprove spam comment" if spam?
    update!(status: :unconfirmed)
  end

  # コメントをスパムとして記録する
  def mark_spam!
    with_lock do
      user.notifications_given.destroy_all
      user.spam_detect!
      update!(status: :spam)
    end
  end

  # スパムコメントを未確認に戻す
  def unmark_spam!
    return if unconfirmed?
    raise "Can't unmark spam approved comment" if approved?
    update!(status: :unconfirmed)
  end

  # コメントオブジェクトを作成する
  # 投稿者がスパム投稿者の場合、スパムコメントとして作成する
  def self.build_from(project, user, params)
    build(params).tap do |project_comment|
      project_comment.project = project
      project_comment.user = user
      project_comment.status = :spam if user.spammer?
    end
  end
end
