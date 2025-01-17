class Admin::AnnouncementsController < Admin::ApplicationController
  before_action :set_announcement, only: %i[show edit update destroy]

  def index
    @announcements = Announcement.all
  end

  def show; end

  def new
    @announcement = Announcement.new
  end

  def edit; end

  def create
    @announcement = Announcement.new(announcement_params)
    if @announcement.save
      redirect_to admin_announcements_path, notice: 'お知らせを作成しました。'
    else
      render :new
    end
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path, notice: 'お知らせを更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @announcement.destroy
    redirect_to admin_announcements_path, notice: 'お知らせを削除しました。'
  end

  private

  def set_announcement
    @announcement = Announcement.find(params[:id])
  end

  def announcement_params
    params.require(:announcement).permit(:title_ja, :title_en, :content_ja, :content_en, :start_at, :end_at)
  end
end
