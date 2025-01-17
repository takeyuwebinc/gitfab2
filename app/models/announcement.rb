# == Schema Information
#
# Table name: announcements
#
#  id                         :bigint(8)        not null, primary key
#  content_en(本文（英語）)   :text(65535)      not null
#  content_ja(本文（日本語）) :text(65535)      not null
#  end_at(掲載終了日時)       :datetime         not null
#  start_at(掲載開始日時)     :datetime         not null
#  title_en(見出し（英語）)   :string(255)      not null
#  title_ja(見出し（日本語）) :string(255)      not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
class Announcement < ApplicationRecord
  validates :title_ja, presence: true
  validates :title_en, presence: true
  validates :content_ja, presence: true
  validates :content_en, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  scope :within_display_period, -> (now: Time.current) do
    where("start_at <= :now AND end_at > :now", now:)
  end
end
