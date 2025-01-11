class Admin::ProjectComments::ApprovalsController < Admin::ApplicationController
  def create
    @project_comment = ProjectComment.find(params[:project_comment_id])
    @project_comment.approve!
    redirect_to admin_project_comments_path(status: params[:status]), notice: "コメントを承認しました"
  end

  def destroy
    @project_comment = ProjectComment.find(params[:project_comment_id])
    @project_comment.unapprove!
    redirect_to admin_project_comments_path(status: params[:status]), notice: "コメントの承認を取り消ししました"
  end
end
  