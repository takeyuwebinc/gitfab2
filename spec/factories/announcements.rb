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
FactoryBot.define do
  factory :announcement do
    title_ja { "<b>MyString</b>" }
    title_en { "<b>MyString</b>" }
    content_ja { "MyText<br>MyText" }
    content_en { "MyText<br>MyText" }
    start_at { Time.current }
    end_at { 1.hours.from_now }
  end
end
