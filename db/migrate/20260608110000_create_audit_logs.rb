class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs, comment: "管理操作の監査ログ（全種別共通のメタデータ）" do |t|
      t.references :operator, null: false, foreign_key: { to_table: :users }, type: :integer, comment: "操作者（管理者ユーザー）のID"
      t.references :auditable, polymorphic: true, null: false, comment: "監査種別への委譲参照（delegated_type）"

      t.timestamps
    end
  end
end
