module SpammerRestriction
  extend ActiveSupport::Concern

  private

  # 投稿者がスパム投稿者の場合、レコードをスパムとして記録する。
  # 保存自体は許可するが、not_spam 絞り込みにより一般ユーザーには公開されない。
  # 投稿者本人には通常どおり応答を返すため、本人は非公開化に気付かない。
  # コメントの build_from（status = :spam if user.spammer?）と同じ挙動を、
  # 関連経由で生成するレコード（Usage / Annotation / Tag）へ適用する。
  # @param record [#status=] status を持つ SpamMarkable レコード
  def flag_as_spam_if_spammer(record)
    record.status = :spam if current_user&.spammer?
  end

  # スパム投稿者かどうかを判定し、サイレント拒否すべきかを返す
  # @param action_name [String] 実行しようとしたアクション名（ログ用）
  # @param content_type [String] コンテンツ種別（スパム検出ログ用）
  # @return [Boolean] サイレント拒否すべき場合 true
  def spammer_silent_reject?(action_name, content_type: nil)
    return false unless current_user&.spammer?

    log_spammer_rejection(action_name)
    record_spammer_detection_log(content_type || action_name)
    true
  end

  # サイレント拒否のログを出力
  # @param action_name [String] 実行しようとしたアクション名
  def log_spammer_rejection(action_name)
    Rails.logger.info "[SpammerRestriction] Silent rejection: user_id=#{current_user.id}, action=#{action_name}"
  end

  # サイレント拒否時のリダイレクト先
  # @return [String] リダイレクト先のパス
  def spammer_redirect_path
    owner_path(current_user)
  end

  # スパマー検出ログを記録する
  # @param content_type [String] コンテンツ種別
  def record_spammer_detection_log(content_type)
    SpamDetectionLogRecorder.record(
      user: current_user,
      ip_address: request.remote_ip,
      detection_method: "spammer",
      content_type: content_type,
      detection_reason: nil
    )
  end
end
