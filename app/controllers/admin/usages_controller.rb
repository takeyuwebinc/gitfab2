class Admin::UsagesController < Admin::ApplicationController
  def index
    @status = params[:status]
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    usages = Card::Usage.preload(project: :owner).order(id: :desc)
    usages.where!(status: @status) if @status.present?
    usages = usages.for_project(@project.id) if @project
    @usages = usages.page(params[:page]).per(100)
  end
end
