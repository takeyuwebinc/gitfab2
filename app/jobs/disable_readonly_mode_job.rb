# frozen_string_literal: true

class DisableReadonlyModeJob < ApplicationJob
  queue_as :default

  def perform
    unless SystemSetting.readonly_mode_enabled?
      Rails.logger.info "[DisableReadonlyModeJob] Readonly mode already disabled, skipping."
      return
    end

    expires_at = SystemSetting.readonly_mode_expires_at
    if expires_at.nil? || expires_at > Time.current
      Rails.logger.info "[DisableReadonlyModeJob] Readonly mode expires_at not reached or cleared, skipping."
      return
    end

    SystemSetting.disable_readonly_mode!
    Rails.logger.info "[DisableReadonlyModeJob] Readonly mode disabled by scheduled job."
  end
end
