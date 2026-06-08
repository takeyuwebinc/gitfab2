class AddSpamHiddenAtToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :spam_hidden_at, :datetime
    add_index :projects, :spam_hidden_at
  end
end
