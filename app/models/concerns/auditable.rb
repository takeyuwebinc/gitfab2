# 監査ログ（AuditLog）の委譲先（種別別モデル）が持つ共通責務。
# delegated_type の subtype として AuditLog と1対1で結びつき、操作者・発生日時は
# 委譲元の AuditLog 側に保持される。新しい監査種別はこの責務を include して追加する。
module Auditable
  extend ActiveSupport::Concern

  included do
    has_one :audit_log, as: :auditable, inverse_of: :auditable, dependent: :destroy
  end

  # 操作者は委譲元 AuditLog が保持する。
  delegate :operator, to: :audit_log
end
