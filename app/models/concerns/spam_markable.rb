module SpamMarkable
  extend ActiveSupport::Concern

  include SpamModerationAuditable

  included do
    enum :status, { unconfirmed: 0, approved: 1, spam: 2 }

    after_save :record_spam_moderation_audit
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

  # スパム記録を未確認に戻す。mark_spam! の対操作として、投稿者の Spammer 登録も
  # 解除する。spam_undetect! は登録が無くても何もしない（冪等）ため、他にスパム投稿が
  # 残っていても無条件に解除される。spam_author を特定できない場合は status の変更のみ行う。
  def unmark_spam!
    return if unconfirmed?
    raise "Can't unmark spam approved comment" if approved?
    with_lock do
      if (author = spam_author)
        author.spam_undetect!
      end
      update!(status: :unconfirmed)
    end
  end

  private

  # スパムへの遷移を「記録」、スパムからの遷移を「取消」として監査ログに残す。
  # spam を含まない遷移（approved→未確認 等）は対象外。状態変更と同一トランザクション
  # 内で発火するため、記録失敗時は状態変更ごとロールバックする。
  def record_spam_moderation_audit
    return unless saved_change_to_status?

    before, after = saved_change_to_status
    if after == "spam"
      write_spam_moderation_audit(:marked)
    elsif before == "spam"
      write_spam_moderation_audit(:unmarked)
    end
  end
end
