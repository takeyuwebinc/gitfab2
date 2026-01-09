class CreateSystemSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :system_settings, comment: "システム設定" do |t|
      t.string :key, null: false, comment: "設定キー（一意）"
      t.text :value, comment: "設定値"

      t.timestamps
    end
    add_index :system_settings, :key, unique: true
  end
end
