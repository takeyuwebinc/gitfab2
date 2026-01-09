# frozen_string_literal: true

class Admin::SystemSettingsController < Admin::ApplicationController
  def edit
    @recaptcha_score_threshold = SystemSetting.recaptcha_score_threshold
  end

  def update
    SystemSetting.recaptcha_score_threshold = params[:recaptcha_score_threshold]
    redirect_to edit_admin_system_settings_path, notice: "設定を保存しました。"
  rescue StandardError => e
    Rails.logger.error "[SystemSettings] Update failed: #{e.message}"
    flash.now[:alert] = "設定の保存に失敗しました。"
    @recaptcha_score_threshold = params[:recaptcha_score_threshold]
    render :edit, status: :unprocessable_entity
  end
end
