class Admin::Comments::ApprovalsController < Admin::Comments::BaseController
  def create
    fetch_markable.approve!
    redirect_to markable_index_path(status: params[:status]), notice: "承認しました"
  end

  def destroy
    fetch_markable.unapprove!
    redirect_to markable_index_path(status: params[:status]), notice: "承認を取り消しました"
  end
end
