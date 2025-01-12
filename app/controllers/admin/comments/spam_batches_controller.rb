class Admin::Comments::SpamBatchesController < Admin::Comments::BaseController
  def create
    comment_class.unconfirmed.where("created_at <= ?", Time.zone.parse(params[:before])).order(id: :asc).find_each do |comment|
      comment.mark_spam!
    end
    redirect_to public_send(:"admin_#{comment_class.name.underscore.pluralize}_path", status: params[:status]), notice: "コメントをスパムとして記録しました"
  end
end
 