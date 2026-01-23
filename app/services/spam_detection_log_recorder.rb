class SpamDetectionLogRecorder
  class << self
    # スパム検出ログを記録する
    # @param user [User] ブロックされたユーザー
    # @param ip_address [String] リクエスト元のIPアドレス
    # @param detection_method [String] 検出方法（keyword, spammer, recaptcha）
    # @param content_type [String] コンテンツ種別
    # @param detection_reason [String, nil] 検出理由の詳細情報
    # @return [SpamDetectionLog, nil] 作成されたログレコード、または失敗時はnil
    def record(user:, ip_address:, detection_method:, content_type:, detection_reason: nil)
      SpamDetectionLog.create!(
        user: user,
        ip_address: ip_address,
        detection_method: detection_method,
        content_type: content_type,
        detection_reason: detection_reason
      )
    rescue StandardError => e
      Rails.logger.error("[SpamDetectionLogRecorder] Failed to record log: #{e.message}")
      nil
    end
  end
end
