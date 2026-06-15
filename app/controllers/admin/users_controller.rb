class Admin::UsersController < Admin::ApplicationController
  def index
    @users = User.order(:id)
    if params[:q].present?
      pattern = "%#{User.sanitize_sql_like(params[:q])}%"
      @users = @users.where("name LIKE :pattern OR email LIKE :pattern", pattern: pattern)
    end
    @users = @users.system_admin if params[:admin_only].present?
    @users = @users.page(params[:page])
  end
end
