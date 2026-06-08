# 監査ログ（AuditLog）の委譲先（種別別モデル）が持つ共通責務。
# delegated_type の subtype として AuditLog と1対1で結びつき、操作者・発生日時は
# 委譲元の AuditLog 側に保持される。新しい監査種別はこの責務を include して追加する。
#
# 汎用の監査ログ閲覧は subtype の内部構造を知らず、ここで定める表示責務（種別ラベル・
# 操作ラベル・対象記述）のみに依存する。各 subtype はこの3メソッドを実装する義務を負う。
# 返すのは人間可読な短いラベル/対象記述に限り、HTML 整形・リンク化・列レイアウトは
# ビュー側の責務とする。
module Auditable
  extend ActiveSupport::Concern

  included do
    has_one :audit_log, as: :auditable, inverse_of: :auditable, dependent: :destroy
  end

  # 操作者は委譲元 AuditLog が保持する。
  delegate :operator, to: :audit_log

  # 種別ラベル（どの監査か）。
  def audit_type_label
    raise NotImplementedError, "#{self.class} must implement #audit_type_label"
  end

  # 操作ラベル（何をしたか）。
  def action_label
    raise NotImplementedError, "#{self.class} must implement #action_label"
  end

  # 対象記述（誰／何に対してか、人間可読な短い表現）。対象の表現方法が subtype ごとに
  # 異なる差異は各 subtype がこの実装内で吸収する。
  def target_description
    raise NotImplementedError, "#{self.class} must implement #target_description"
  end
end
