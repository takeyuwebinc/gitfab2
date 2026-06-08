class Admin::TagsController < Admin::ApplicationController
  def index
    @status = params[:status]
    tags = Tag.preload(:user, project: :owner).order(id: :desc)
    tags.where!(status: @status) if @status.present?
    @tags = tags.page(params[:page]).per(100)
  end
end
