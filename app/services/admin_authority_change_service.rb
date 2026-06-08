# frozen_string_literal: true

# 管理者権限（users.authority が 'admin' か否か）の付与・剥奪を行う。
#
# 誤操作による管理不能状態を防ぐため、剥奪では「操作者自身の剥奪」と「最後の1名の
# 剥奪」を拒否する。最後の1名判定と更新は、複数の管理者が同時に剥奪して0名化する競合を
# 防ぐため、管理者集合を悲観的ロック（FOR UPDATE）で直列化したうえで同一トランザクション
# 内で行う。対象行のみのロックでは異なる対象を同時剥奪する競合を直列化できないため、
# 管理者集合全体をロックする。
#
# 監査記録は、権限が実際に変化した付与・剥奪に限り、状態変更と同一トランザクション内で
# 残す。状態が変わらない操作（既に管理者への付与、既に一般への剥奪）は冪等に成功扱いとし、
# 記録しない。認可（操作者が管理者であること）は呼び出し側の責務とする。
class AdminAuthorityChangeService
  Result = Data.define(:success, :changed, :error) do
    def success? = success
  end

  AUTHORITY_ADMIN = "admin"

  def self.grant(target_user:, operator:)
    new(operator:).grant(target_user)
  end

  def self.revoke(target_user:, operator:)
    new(operator:).revoke(target_user)
  end

  def initialize(operator:)
    @operator = operator
  end

  def grant(target_user)
    ActiveRecord::Base.transaction do
      target_user.lock!

      if target_user.is_system_admin?
        Result.new(success: true, changed: false, error: nil)
      else
        target_user.update!(authority: AUTHORITY_ADMIN)
        write_audit(:grant, target_user)
        Result.new(success: true, changed: true, error: nil)
      end
    end
  end

  def revoke(target_user)
    return Result.new(success: false, changed: false, error: :self) if target_user.id == @operator.id

    ActiveRecord::Base.transaction do
      admin_ids = User.where(authority: AUTHORITY_ADMIN).lock.to_a.map(&:id)

      if admin_ids.exclude?(target_user.id)
        Result.new(success: true, changed: false, error: nil)
      elsif (admin_ids - [target_user.id]).empty?
        Result.new(success: false, changed: false, error: :last_one)
      else
        target_user.update!(authority: nil)
        write_audit(:revoke, target_user)
        Result.new(success: true, changed: true, error: nil)
      end
    end
  end

  # 付与が可能か（事前判定用）。操作者がシステム管理者であること。
  # 認可（Ability・コントローラ）が参照する読み取り述語。状態は変更しない。
  def can_grant?(_target_user)
    @operator.is_system_admin?
  end

  # 剥奪が可能か（事前判定用）。操作者がシステム管理者であり、対象が操作者自身でなく、
  # 対象が最後のシステム管理者でないこと。最後の1名のレース判定は revoke の同一
  # トランザクション内ロックが最終防御として別途担うため、本述語は事前判定に用いる。
  def can_revoke?(target_user)
    @operator.is_system_admin? &&
      target_user.id != @operator.id &&
      !target_user.last_system_admin?
  end

  private

  def write_audit(action, target_user)
    AuditLog.create!(
      operator: @operator,
      ip_address: Current.ip_address,
      auditable: AdminAuthorityAudit.new(action:, target_user:)
    )
  end
end
