# スパム手動認定の監査ログ（種別別の詳細）。操作種別（記録/取消）と認定対象（種別＋ID）
# を保持する。操作者・発生日時は委譲元の AuditLog が持つ。AuditLog の最初の委譲先。
# 対象は緩い参照（FK制約を張らない）とし、対象が削除されても監査記録は残す。
#
# 対象は種別＋ID のみを保持し、コメント本文などの個人情報は記録しない。スパム認定は
# 非破壊（status / spam_hidden_at）で対象実体が残るため、本文が必要なら参照で辿れる。
class SpamModerationAudit < ApplicationRecord
  include Auditable

  enum :action, { marked: 0, unmarked: 1 }

  belongs_to :target, polymorphic: true

  ACTION_LABELS = { "marked" => "記録", "unmarked" => "取消" }.freeze

  def audit_type_label
    "スパム認定"
  end

  # 操作種別の日本語表示。
  def action_label
    ACTION_LABELS.fetch(action)
  end

  # 対象は種別＋ID で表す。対象実体は非破壊で残るため、必要なら種別＋ID から辿れる。
  def target_description
    "#{target_type}##{target_id}"
  end
end
