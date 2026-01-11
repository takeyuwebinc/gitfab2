module SpammerRestriction
  extend ActiveSupport::Concern

  private

  # スパム投稿者かどうかを判定し、サイレント拒否すべきかを返す
  # @param action_name [String] 実行しようとしたアクション名（ログ用）
  # @return [Boolean] サイレント拒否すべき場合 true
  def spammer_silent_reject?(action_name)
    return false unless current_user&.spammer?

    log_spammer_rejection(action_name)
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
end
