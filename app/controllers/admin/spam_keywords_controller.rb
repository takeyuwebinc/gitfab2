class Admin::SpamKeywordsController < Admin::ApplicationController
  before_action :set_spam_keyword, only: %i[edit update destroy toggle_enabled]

  def index
    @spam_keywords = SpamKeyword.order(created_at: :desc).page(params[:page]).per(50)
  end

  def new
    @spam_keyword = SpamKeyword.new
  end

  def create
    @spam_keyword = SpamKeyword.new(spam_keyword_params)
    if @spam_keyword.save
      SpamKeywordDetector.clear_cache
      log_operation(:create, @spam_keyword)
      redirect_to admin_spam_keywords_path, notice: "スパムキーワードを追加しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @spam_keyword.update(spam_keyword_params)
      SpamKeywordDetector.clear_cache
      log_operation(:update, @spam_keyword)
      redirect_to admin_spam_keywords_path, notice: "スパムキーワードを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @spam_keyword.destroy!
    SpamKeywordDetector.clear_cache
    log_operation(:destroy, @spam_keyword)
    redirect_to admin_spam_keywords_path, notice: "スパムキーワードを削除しました"
  end

  def toggle_enabled
    new_enabled = !@spam_keyword.enabled
    @spam_keyword.update!(enabled: new_enabled)
    SpamKeywordDetector.clear_cache

    message = new_enabled ? "スパムキーワードを有効にしました" : "スパムキーワードを無効にしました"
    log_operation(new_enabled ? :enable : :disable, @spam_keyword)
    redirect_to admin_spam_keywords_path, notice: message
  end

  private

  def set_spam_keyword
    @spam_keyword = SpamKeyword.find(params[:id])
  end

  def spam_keyword_params
    params.require(:spam_keyword).permit(:keyword, :enabled)
  end

  def log_operation(operation, spam_keyword)
    Rails.logger.info(
      "[Admin::SpamKeywordsController] #{operation}: " \
      "admin_id=#{current_user.id}, keyword=\"#{spam_keyword.keyword}\""
    )
  end
end
