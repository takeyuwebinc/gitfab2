class Admin::CardCommentsController < Admin::ApplicationController
  def index
    @status = params[:status]
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    card_comments = CardComment.preload(:card, :user).order(id: :desc)
    card_comments.where!(status: @status) if @status.present?
    card_comments = card_comments.for_project(@project.id) if @project
    @card_comments = card_comments.page(params[:page]).per(100)
  end
end
