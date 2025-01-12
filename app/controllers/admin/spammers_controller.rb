class Admin::SpammersController < Admin::ApplicationController
  def index
    @spammers = Spammer.eager_load(:user).order(created_at: :desc).page(params[:page]).per(100)
  end

  def destroy
    Spammer.find(params[:id]).destroy!
    redirect_to admin_spammers_path, notice: 'スパム報告を削除しました'
  end
end
