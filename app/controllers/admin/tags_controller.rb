class Admin::TagsController < Admin::ApplicationController
  def index
    @status = params[:status]
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    tags = Tag.preload(:user, project: :owner).order(id: :desc)
    tags.where!(status: @status) if @status.present?
    tags = tags.for_project(@project.id) if @project
    @tags = tags.page(params[:page]).per(100)
  end
end
