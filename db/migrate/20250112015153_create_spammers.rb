class CreateSpammers < ActiveRecord::Migration[7.2]
  def change
    create_table :spammers do |t|
      t.references :user, null: false, foreign_key: true, type: :integer, index: { unique: true }
      t.timestamp :detected_at, null: true, comment: 'スパムとして検知された日時'

      t.timestamps
    end
  end
end
