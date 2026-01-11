# frozen_string_literal: true

module ReadonlyModeRestriction
  extend ActiveSupport::Concern

  READONLY_MODE_ERROR_MESSAGE = "The site is currently in maintenance mode. Posting and editing are temporarily unavailable."

  private

  # before_action用: リードオンリーモード中は処理を中断する
  def restrict_readonly_mode
    readonly_mode_restricted?
  end

  # リードオンリーモード中かどうかを判定し、制限すべきかを返す
  # 制限対象の場合、適切なレスポンスを返して処理を中断する
  # @return [Boolean] 処理を中断すべき場合 true
  def readonly_mode_restricted?
    return false unless SystemSetting.readonly_mode_enabled?

    log_readonly_mode_rejection
    respond_with_readonly_mode_error
    true
  end

  # リードオンリーモード中のエラーレスポンスを返す
  def respond_with_readonly_mode_error
    respond_to do |format|
      format.html do
        flash[:alert] = READONLY_MODE_ERROR_MESSAGE
        redirect_back(fallback_location: root_path)
      end
      format.js do
        render json: { success: false, error: READONLY_MODE_ERROR_MESSAGE },
               status: :service_unavailable,
               content_type: "application/json"
      end
      format.json do
        render json: { success: false, error: READONLY_MODE_ERROR_MESSAGE }, status: :service_unavailable
      end
      format.any do
        flash[:alert] = READONLY_MODE_ERROR_MESSAGE
        redirect_back(fallback_location: root_path)
      end
    end
  end

  # リードオンリーモード中の操作拒否ログを出力
  def log_readonly_mode_rejection
    user_info = current_user ? "user_id=#{current_user.id}" : "anonymous"
    Rails.logger.warn "[ReadonlyMode] Request rejected: #{user_info}, ip=#{request.remote_ip}, path=#{request.path}"
  end
end
