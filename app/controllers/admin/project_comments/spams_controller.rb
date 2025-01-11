class Admin::ProjectComments::SpamsController < Admin::ApplicationController
  def create
    @project_comment = ProjectComment.find(params[:project_comment_id])
    @project_comment.mark_spam!
    redirect_to admin_project_comments_path(status: params[:status]), notice: "コメントをスパムとして記録しました"
  end

  def destroy
    @project_comment = ProjectComment.find(params[:project_comment_id])
    @project_comment.unmark_spam!
    redirect_to admin_project_comments_path(status: params[:status]), notice: "スパムコメントを未確認に戻しました"
  end
end
    