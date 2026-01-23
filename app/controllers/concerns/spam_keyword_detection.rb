module SpamKeywordDetection
  extend ActiveSupport::Concern

  private

  # スパムキーワード検出を行い、検出された場合は true を返す
  # @param contents [Array<String>, String] 検出対象の文字列
  # @param content_type [String] 投稿種別
  # @return [Boolean] スパムキーワードが検出された場合 true
  def detect_spam_keyword(contents:, content_type:)
    detected = SpamKeywordDetector.detect_with_logging(
      user: current_user,
      contents: contents,
      content_type: content_type
    )

    if detected
      @spam_keyword_rejection_message = detected.rejection_message
      record_spam_detection_log(
        detection_method: "keyword",
        content_type: content_type,
        detection_reason: detected.keyword
      )
      true
    else
      false
    end
  end

  # 検出されたスパムキーワードの拒否メッセージを取得
  # @return [String, nil]
  def spam_keyword_rejection_message
    @spam_keyword_rejection_message
  end

  # スパム検出ログを記録する
  # @param detection_method [String] 検出方法
  # @param content_type [String] コンテンツ種別
  # @param detection_reason [String, nil] 検出理由
  def record_spam_detection_log(detection_method:, content_type:, detection_reason: nil)
    SpamDetectionLogRecorder.record(
      user: current_user,
      ip_address: request.remote_ip,
      detection_method: detection_method,
      content_type: content_type,
      detection_reason: detection_reason
    )
  end
end
