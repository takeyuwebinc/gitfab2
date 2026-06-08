class AddStatusToCardsAndTags < ActiveRecord::Migration[7.2]
  def change
    add_column :cards, :status, :integer, default: 0, null: false, comment: "確認ステータス 0:未確認 1:承認済み 2:スパム"
    add_column :tags, :status, :integer, default: 0, null: false, comment: "確認ステータス 0:未確認 1:承認済み 2:スパム"
  end
end
