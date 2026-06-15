class Admin::AnnotationsController < Admin::ApplicationController
  def index
    @status = params[:status]
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    annotations = Card::Annotation.preload(state: { project: :owner }).order(id: :desc)
    annotations.where!(status: @status) if @status.present?
    annotations = annotations.for_project(@project.id) if @project
    @annotations = annotations.page(params[:page]).per(100)
  end
end
