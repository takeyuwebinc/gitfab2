class Admin::ApplicationController < ApplicationController
  layout "admin"

  before_action do
    if !current_user || !current_user.is_system_admin?
      redirect_to(root_path)
    else
      # 操作者を監査ログ記録のコールバックから参照できるようにする。設定箇所を
      # admin 認可済みの一点に限定し、操作者の出所を単純化する。
      Current.admin = current_user
    end
  end
end
