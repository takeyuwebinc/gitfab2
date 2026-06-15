class Admin::Comments::SpamsController < Admin::Comments::BaseController
  def create
    fetch_markable.mark_spam!
    redirect_to markable_index_path(**preserved_index_params), notice: "スパムとして記録しました"
  end

  def destroy
    fetch_markable.unmark_spam!
    redirect_to markable_index_path(**preserved_index_params), notice: "スパムの判定を取り消しました"
  end
end
