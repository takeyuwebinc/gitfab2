class Admin::Comments::SpamBatchesController < Admin::Comments::BaseController
  def create
    markable_class.unconfirmed.where("created_at <= ?", Time.zone.parse(params[:before])).order(id: :asc).find_each(&:mark_spam!)
    redirect_to markable_index_path(status: params[:status]), notice: "スパムとして記録しました"
  end
end
