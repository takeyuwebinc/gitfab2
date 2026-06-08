# スパム手動認定の状態遷移を監査ログに記録する責務。記録対象モデル（SpamMarkable を
# 含むコメント系・Project）が状態遷移を検知した際に呼び出す。操作者（Current.admin）が
# 存在する場合のみ記録し、操作者を持たない経路（自動スパム化など）は自然に対象外となる。
# 状態変更と同一トランザクション内で実行され、記録失敗時は状態変更ごとロールバックする。
module SpamModerationAuditable
  extend ActiveSupport::Concern

  private

  # 操作者が存在する場合のみ、対象自身を指すスパム認定監査ログ（委譲元 AuditLog と
  # 委譲先 SpamModerationAudit の1組）を記録する。
  def write_spam_moderation_audit(action)
    operator = Current.admin
    return unless operator

    AuditLog.create!(
      operator: operator,
      ip_address: Current.ip_address,
      auditable: SpamModerationAudit.new(action: action, target: self)
    )
  end
end
