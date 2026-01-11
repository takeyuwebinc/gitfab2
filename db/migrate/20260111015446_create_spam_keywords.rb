class CreateSpamKeywords < ActiveRecord::Migration[7.2]
  def change
    create_table :spam_keywords do |t|
      t.string :keyword, null: false, limit: 255
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
    add_index :spam_keywords, :keyword, unique: true
  end
end
