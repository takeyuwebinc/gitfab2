# 個別ユーザーの管理者権限の付与（create）・剥奪（destroy）を受け付ける。
# 状態遷移・誤操作防止・監査記録は AdminAuthorityChangeService が担い、本コントローラは
# 結果に応じた画面通知とリダイレクトに徹する。検索条件（q・page）は操作後も一覧の
# 表示状態を保つためリダイレクト先へ引き継ぐ。
class Admin::Users::AdminAuthoritiesController < Admin::ApplicationController
  before_action :load_user

  def create
    result = AdminAuthorityChangeService.grant(target_user: @user, operator: current_user)
    redirect_to admin_users_path(q: params[:q], page: params[:page]), **flash_for(:grant, result)
  end

  def destroy
    result = AdminAuthorityChangeService.revoke(target_user: @user, operator: current_user)
    redirect_to admin_users_path(q: params[:q], page: params[:page]), **flash_for(:revoke, result)
  end

  private

  # 一覧の URL は friendly_id の slug を含むため slug で対象を解決する。対象が見つから
  # ない場合（同時削除・不正な URL）は例外で中断せず、一覧へ戻して理由を表示する。
  def load_user
    @user = User.friendly.find(params[:user_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_users_path(q: params[:q], page: params[:page]), alert: "対象のユーザーが見つかりません"
  end

  def flash_for(action, result)
    return { alert: error_message(result.error) } unless result.success?

    { notice: success_message(action, result.changed) }
  end

  def success_message(action, changed)
    if action == :grant
      changed ? "#{@user.name} に管理者権限を付与しました" : "#{@user.name} は既に管理者です"
    else
      changed ? "#{@user.name} の管理者権限を剥奪しました" : "#{@user.name} は既に一般ユーザーです"
    end
  end

  def error_message(error)
    case error
    when :self
      "自分自身の管理者権限は剥奪できません"
    when :last_one
      "最後の管理者の権限は剥奪できません"
    else
      "操作に失敗しました"
    end
  end
end
