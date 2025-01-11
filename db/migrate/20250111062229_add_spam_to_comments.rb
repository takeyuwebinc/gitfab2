class AddSpamToComments < ActiveRecord::Migration[7.2]
  def change
    add_column :project_comments, :spam, :boolean, default: false, null: false, after: :project_id, comment: "スパムコメントとして扱う"
    add_column :card_comments, :spam, :boolean, default: false, null: false, after: :body, comment: "スパムコメントとして扱う"
  end
end
