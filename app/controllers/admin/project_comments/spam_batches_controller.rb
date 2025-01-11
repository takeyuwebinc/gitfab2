class Admin::ProjectComments::SpamBatchesController < Admin::ApplicationController
  def create
    ProjectComment.unconfirmed.where("created_at <= ?", Time.zone.parse(params[:before])).order(id: :asc).find_each do |project_comment|
      project_comment.mark_spam!
    end
    redirect_to admin_project_comments_path(status: params[:status]), notice: "コメントをスパムとして記録しました"
  end
end
 