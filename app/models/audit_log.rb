# 管理操作の監査ログ（全種別共通のメタデータ）。操作者・発生日時を保持し、種別別の
# 詳細は delegated_type で委譲先（SpamModerationAudit 等）に持たせる。共通メタデータと
# 共通クエリ（操作者別・期間別）・共通閲覧UIを全監査種別で共有するための基盤。
# 新しい監査種別は委譲先モデルを追加し types に登録して拡張する。
#
# 監査ログは無期限保持する（自動削除しない）。用途は管理操作の説明責任と不正監査で、
# 現時点で法令上の保持義務はなく、社内運用上の要請による。記録は ID 主体で軽量。
class AuditLog < ApplicationRecord
  belongs_to :operator, class_name: "User"

  delegated_type :auditable, types: %w[SpamModerationAudit], dependent: :destroy

  scope :recent, -> { order(created_at: :desc) }
end
