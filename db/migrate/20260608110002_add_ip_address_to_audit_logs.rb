class AddIpAddressToAuditLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :audit_logs, :ip_address, :string, comment: "操作者のリクエスト元IPアドレス"
  end
end
