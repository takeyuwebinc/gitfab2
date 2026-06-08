class Admin::AuditLogsController < Admin::ApplicationController
  def index
    @audit_logs = AuditLog.recent.includes(:operator, :auditable).page(params[:page]).per(50)
  end
end
