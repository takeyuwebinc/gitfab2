class AddStatusToComments < ActiveRecord::Migration[7.2]
  def change
    add_column :project_comments, :status, :integer, default: 0, null: false, after: :project_id, comment: "確認ステータス 0:未確認 1:承認済み 2:スパム"
    add_column :card_comments, :status, :integer, default: 0, null: false, after: :body, comment: "確認ステータス 0:未確認 1:承認済み 2:スパム"
  end
end
