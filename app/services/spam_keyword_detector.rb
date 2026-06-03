class SpamKeywordDetector
  CACHE_KEY = "spam_keywords/enabled"

  # ゼロ幅文字。NFKC 正規化（unicode_normalize(:nfkc)）はこれらを除去しないため、
  # 照合の前段で明示的に取り除く。
  ZERO_WIDTH_PATTERN = /[\u200B\u200C\u200D\uFEFF]/

  # 文字分断に使われる空白・区切り記号。検出対象とキーワードの双方からこれらを
  # 取り除いてから照合することで、文字間に記号や空白を挟む迂回を吸収する。
  SEPARATOR_PATTERN = /[[:space:]_.\-*'"`~^|\/\\(){}\[\]<>]/

  class << self
    # スパムキーワードを検出し、検出されたSpamKeywordオブジェクトを返す
    # @param user [User] 投稿ユーザー（ログ出力用、検出判定には使用しない）
    # @param contents [Array<String>, String] 検出対象の文字列（単一または複数）
    # @return [SpamKeyword, nil] 検出されたキーワード、または nil
    def detect(user:, contents:)
      contents_array = Array(contents).compact
      return nil if contents_array.empty?

      normalized_content = normalize(contents_array.join(" "))
      enabled_keywords.find do |keyword|
        normalized_keyword = normalize(keyword.keyword)
        # 正規化で空になったキーワード（区切り記号のみ等）は照合から除く。
        # 空文字は String#include? が常に真を返し、全投稿を誤検知するため。
        normalized_keyword.present? && normalized_content.include?(normalized_keyword)
      end
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

    # 検出対象・キーワードを照合用の正規形へ変換する。
    # NFKC で全角/半角・合成文字・特殊空白を統一し、ゼロ幅文字と区切り記号を除去し、
    # 小文字化する。これにより文字分断・全角半角混在・ゼロ幅文字による迂回を吸収する。
    def normalize(text)
      text.unicode_normalize(:nfkc)
          .gsub(ZERO_WIDTH_PATTERN, "")
          .gsub(SEPARATOR_PATTERN, "")
          .downcase
    end

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
