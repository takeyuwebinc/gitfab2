class SpamKeywordDetector
  CACHE_KEY = "spam_keywords/enabled"

  class << self
    # スパムキーワードを検出し、検出されたSpamKeywordオブジェクトを返す
    # @param user [User] 投稿ユーザー（ログ出力用、検出判定には使用しない）
    # @param contents [Array<String>, String] 検出対象の文字列（単一または複数）
    # @return [SpamKeyword, nil] 検出されたキーワード、または nil
    def detect(user:, contents:)
      contents_array = Array(contents).compact
      return nil if contents_array.empty?

      combined_content = contents_array.join(" ").downcase
      enabled_keywords.find { |keyword| combined_content.include?(keyword.keyword.downcase) }
    end

    # スパムキーワード検出を行い、検出された場合はログを出力する
    # @param user [User] 投稿ユーザー
    # @param contents [Array<String>, String] 検出対象の文字列
    # @param content_type [String] 投稿種別（Project, ProjectComment, CardComment など）
    # @return [SpamKeyword, nil] 検出されたキーワード、または nil
    def detect_with_logging(user:, contents:, content_type:)
      detected = detect(user: user, contents: contents)
      return nil unless detected

      log_detection(
        user_id: user.id,
        content_type: content_type,
        keyword: detected.keyword,
        content: Array(contents).compact.join(" ").truncate(100)
      )

      detected
    end

    # キャッシュをクリアする（キーワード変更時に呼び出す）
    def clear_cache
      Rails.cache.delete(CACHE_KEY)
    end

    private

    def enabled_keywords
      Rails.cache.fetch(CACHE_KEY, expires_in: 1.hour) do
        SpamKeyword.enabled.to_a
      end
    end

    def log_detection(user_id:, content_type:, keyword:, content:)
      Rails.logger.info(
        "[SpamKeywordDetector] Spam keyword detected: " \
        "user_id=#{user_id}, type=#{content_type}, keyword=\"#{keyword}\", content=\"#{content}\""
      )
    end
  end
end
