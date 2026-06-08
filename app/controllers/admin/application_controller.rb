class Admin::ApplicationController < ApplicationController
  layout "admin"

  before_action do
    if !current_user || !current_user.is_system_admin?
      redirect_to(root_path)
    else
      # 操作者とリクエスト元 IP を監査ログ記録のコールバックから参照できるようにする。
      # 設定箇所を admin 認可済みの一点に限定し、出所を単純化する。
      Current.admin = current_user
      Current.ip_address = request.remote_ip
    end
  end
end
