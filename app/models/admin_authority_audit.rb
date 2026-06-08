# 管理者権限変更の監査ログ（種別別の詳細）。操作種別（付与/剥奪）と対象ユーザーを
# 保持する。操作者・発生日時は委譲元の AuditLog が持つ。SpamModerationAudit と並列の
# AuditLog 委譲先。
#
# 対象は常にユーザーであるため、ポリモーフィックではなくユーザーへの直接参照とする。
# 対象は緩い参照（FK制約を張らない）とし、対象ユーザーが削除されても監査記録は残す。
# 削除後は target_user が nil になりうるため、対象記述はそれを許容する。
class AdminAuthorityAudit < ApplicationRecord
  include Auditable

  enum :action, { grant: 0, revoke: 1 }

  belongs_to :target_user, class_name: "User", optional: true

  ACTION_LABELS = { "grant" => "付与", "revoke" => "剥奪" }.freeze

  def audit_type_label
    "管理者権限変更"
  end

  def action_label
    ACTION_LABELS.fetch(action)
  end

  def target_description
    target_user ? target_user.name : "(削除済みユーザー ##{target_user_id})"
  end
end
