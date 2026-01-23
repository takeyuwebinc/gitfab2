module RecaptchaDetectionLogging
  extend ActiveSupport::Concern

  private

  # reCAPTCHA検証失敗のログを記録する
  # @param content_type [String] コンテンツ種別
  # @param detection_reason [String, nil] 検出理由（score=X, threshold=Y）
  def record_recaptcha_detection_log(content_type, detection_reason)
    SpamDetectionLogRecorder.record(
      user: current_user,
      ip_address: request.remote_ip,
      detection_method: "recaptcha",
      content_type: content_type,
      detection_reason: detection_reason
    )
  end
end
