class CreateAdminAuthorityAudits < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_authority_audits, comment: "管理者権限変更の監査ログ（種別別の詳細）" do |t|
      t.integer :action, null: false, comment: "操作種別（0: 付与, 1: 剥奪）"
      t.bigint :target_user_id, null: false, comment: "対象ユーザー（緩い参照、FK制約なし）"

      t.timestamps
    end

    add_index :admin_authority_audits, :target_user_id
  end
end
