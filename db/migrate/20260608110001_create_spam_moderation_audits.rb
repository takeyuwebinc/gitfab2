class CreateSpamModerationAudits < ActiveRecord::Migration[7.2]
  def change
    create_table :spam_moderation_audits, comment: "スパム手動認定の監査ログ（種別別の詳細）" do |t|
      t.integer :action, null: false, comment: "操作種別（0: 記録, 1: 取消）"
      t.references :target, polymorphic: true, null: false, comment: "認定対象コンテンツ（種別＋ID、緩い参照）"

      t.timestamps
    end
  end
end
