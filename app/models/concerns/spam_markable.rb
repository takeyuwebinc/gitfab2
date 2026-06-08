module SpamMarkable
  extend ActiveSupport::Concern

  included do
    enum :status, { unconfirmed: 0, approved: 1, spam: 2 }
  end

  # 承認する
  def approve!
    update!(status: :approved)
  end

  # 承認を解除する
  def unapprove!
    return if unconfirmed?
    raise "Can't unapprove spam comment" if spam?
    update!(status: :unconfirmed)
  end

  # スパムマークの起因となる投稿者を返す。デフォルトは user 関連。
  # 作成者を特定できないレコードでは nil を返す。nil の場合は Spammer 登録・
  # 通知削除を行わず、status の変更のみ行う。
  def spam_author
    user
  end

  # スパムとして記録する
  def mark_spam!
    with_lock do
      if (author = spam_author)
        author.notifications_given.destroy_all
        author.spam_detect!
      end
      update!(status: :spam)
    end
  end

  # スパム記録を未確認に戻す
  def unmark_spam!
    return if unconfirmed?
    raise "Can't unmark spam approved comment" if approved?
    update!(status: :unconfirmed)
  end
end
