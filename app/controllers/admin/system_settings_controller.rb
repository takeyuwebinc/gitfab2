# frozen_string_literal: true

class Admin::SystemSettingsController < Admin::ApplicationController
  def edit
    @recaptcha_score_threshold = SystemSetting.recaptcha_score_threshold
    @readonly_mode_enabled = SystemSetting.readonly_mode_enabled?
    @readonly_mode_expires_at = SystemSetting.readonly_mode_expires_at
  end

  def update
    update_recaptcha_settings
    update_readonly_mode_settings
    redirect_to edit_admin_system_settings_path, notice: "設定を保存しました。"
  rescue StandardError => e
    Rails.logger.error "[SystemSettings] Update failed: #{e.message}"
    flash.now[:alert] = "設定の保存に失敗しました。"
    load_params_for_rerender
    render :edit, status: :unprocessable_entity
  end

  private

  def update_recaptcha_settings
    SystemSetting.recaptcha_score_threshold = params[:recaptcha_score_threshold]
  end

  def update_readonly_mode_settings
    readonly_mode_enabled = params[:readonly_mode_enabled] == "1"

    if readonly_mode_enabled
      expires_at = parse_expires_at
      SystemSetting.enable_readonly_mode!(expires_at: expires_at)
    else
      SystemSetting.disable_readonly_mode!
    end
  end

  def parse_expires_at
    return nil if params[:readonly_mode_expires_at].blank?

    Time.zone.parse(params[:readonly_mode_expires_at])
  end

  def load_params_for_rerender
    @recaptcha_score_threshold = params[:recaptcha_score_threshold]
    @readonly_mode_enabled = params[:readonly_mode_enabled] == "1"
    @readonly_mode_expires_at = parse_expires_at
  end
end
