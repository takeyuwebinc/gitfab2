class Admin::Comments::SpamsController < Admin::Comments::BaseController
  def create
    fetch_markable.mark_spam!
    redirect_to markable_index_path(status: params[:status]), notice: "スパムとして記録しました"
  end

  def destroy
    fetch_markable.unmark_spam!
    redirect_to markable_index_path(status: params[:status]), notice: "スパムの判定を取り消しました"
  end
end
