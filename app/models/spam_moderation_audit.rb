# スパム手動認定の監査ログ（種別別の詳細）。操作種別（記録/取消）と認定対象（種別＋ID）
# を保持する。操作者・発生日時は委譲元の AuditLog が持つ。AuditLog の最初の委譲先。
# 対象は緩い参照（FK制約を張らない）とし、対象が削除されても監査記録は残す。
class SpamModerationAudit < ApplicationRecord
  include Auditable

  enum :action, { marked: 0, unmarked: 1 }

  belongs_to :target, polymorphic: true

  ACTION_LABELS = { "marked" => "記録", "unmarked" => "取消" }.freeze

  # 操作種別の日本語表示。
  def action_label
    ACTION_LABELS.fetch(action)
  end
end
