class Admin::SpamDetectionLogsController < Admin::ApplicationController
  def index
    @spam_detection_logs = SpamDetectionLog.recent.includes(:user).page(params[:page]).per(50)
  end
end
