class Admin::Comments::SpamBatchesController < Admin::Comments::BaseController
  def create
    # for_project が cards を結合する場合に created_at が曖昧にならないよう、
    # 対象モデル自身のテーブルで修飾する。
    scope = markable_class.unconfirmed.where("#{markable_class.table_name}.created_at <= ?", Time.zone.parse(params[:before]))
    scope = scope.for_project(params[:project_id]) if params[:project_id].present?
    scope.order(id: :asc).find_each(&:mark_spam!)
    redirect_to markable_index_path(**preserved_index_params), notice: "スパムとして記録しました"
  end
end
