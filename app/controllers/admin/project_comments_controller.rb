class Admin::ProjectCommentsController < Admin::ApplicationController
  def index
    @status = params[:status]
    project_comments = ProjectComment.preload(:project).order(id: :desc)
    project_comments.where!(status: @status) if @status.present?
    @project_comments = project_comments.page(params[:page]).per(100)
  end
end
