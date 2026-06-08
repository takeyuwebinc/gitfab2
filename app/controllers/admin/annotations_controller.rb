class Admin::AnnotationsController < Admin::ApplicationController
  def index
    @status = params[:status]
    annotations = Card::Annotation.preload(state: { project: :owner }).order(id: :desc)
    annotations.where!(status: @status) if @status.present?
    @annotations = annotations.page(params[:page]).per(100)
  end
end
