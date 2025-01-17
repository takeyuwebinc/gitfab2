class CreateAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :announcements, comment: "お知らせ" do |t|
      t.string :title_ja, null: false, comment: "見出し（日本語）"
      t.string :title_en, null: false, comment: "見出し（英語）"
      t.text :content_ja, null: false, comment: "本文（日本語）"
      t.text :content_en, null: false, comment: "本文（英語）"
      t.datetime :start_at, null: false, comment: "掲載開始日時"
      t.datetime :end_at, null: false, comment: "掲載終了日時"

      t.timestamps
    end
  end
end
