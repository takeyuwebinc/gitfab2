module SpamCommentable
  extend ActiveSupport::Concern

  included do
    enum :status, { unconfirmed: 0, approved: 1, spam: 2 }
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
end
