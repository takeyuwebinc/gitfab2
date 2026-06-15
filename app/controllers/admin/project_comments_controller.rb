class Admin::ProjectCommentsController < Admin::ApplicationController
  def index
    @status = params[:status]
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    project_comments = ProjectComment.preload(:project, :user).order(id: :desc)
    project_comments.where!(status: @status) if @status.present?
    project_comments = project_comments.for_project(@project.id) if @project
    @project_comments = project_comments.page(params[:page]).per(100)
  end
end
