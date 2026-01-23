class CreateSpamDetectionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :spam_detection_logs, comment: "スパム検出ログ" do |t|
      t.references :user, null: false, foreign_key: true, type: :integer, comment: "ブロックされたユーザーのID"
      t.string :ip_address, null: false, comment: "リクエスト元のIPアドレス"
      t.string :detection_method, null: false, comment: "検出方法（keyword, spammer, recaptcha）"
      t.text :detection_reason, comment: "検出理由の詳細情報"
      t.string :content_type, null: false, comment: "コンテンツ種別（Project, NoteCard等）"

      t.timestamps
    end
  end
end
