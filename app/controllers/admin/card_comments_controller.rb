class Admin::CardCommentsController < Admin::ApplicationController
  def index
    @status = params[:status]
    card_comments = CardComment.preload(:card, :user).order(id: :desc)
    card_comments.where!(status: @status) if @status.present?
    @card_comments = card_comments.page(params[:page]).per(100)
  end
end
