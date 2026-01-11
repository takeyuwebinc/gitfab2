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
end
