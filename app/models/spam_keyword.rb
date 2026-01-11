class SpamKeyword < ApplicationRecord
  validates :keyword, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :enabled, inclusion: { in: [ true, false ] }

  scope :enabled, -> { where(enabled: true) }

  before_validation :strip_keyword

  # 伏字付きキーワードを返す（3文字以下はnil）
  def masked_keyword
    return nil if keyword.length <= 3
    first_char = keyword[0]
    last_char = keyword[-1]
    middle_mask = "*" * (keyword.length - 2)
    "#{first_char}#{middle_mask}#{last_char}"
  end

  # 拒否時のエラーメッセージを生成
  def rejection_message
    masked = masked_keyword
    if masked
      "禁止されているキーワード「#{masked}」が含まれているため、投稿できませんでした。内容を修正してください。"
    else
      "禁止されているキーワードが含まれているため、投稿できませんでした。内容を修正してください。"
    end
  end

  private

  def strip_keyword
    self.keyword = keyword&.strip
  end
end
