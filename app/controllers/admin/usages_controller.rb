class Admin::UsagesController < Admin::ApplicationController
  def index
    @status = params[:status]
    usages = Card::Usage.preload(project: :owner).order(id: :desc)
    usages.where!(status: @status) if @status.present?
    @usages = usages.page(params[:page]).per(100)
  end
end
