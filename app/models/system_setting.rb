# frozen_string_literal: true

class SystemSetting < ApplicationRecord
  RECAPTCHA_SCORE_THRESHOLD = "recaptcha_score_threshold"
  RECAPTCHA_SCORE_THRESHOLD_DEFAULT = 0.5

  READONLY_MODE_ENABLED = "readonly_mode_enabled"
  READONLY_MODE_EXPIRES_AT = "readonly_mode_expires_at"

  CACHE_KEY_READONLY_MODE = "system_setting:readonly_mode"

  validates :key, presence: true, uniqueness: true

  class << self
    def get(key, default: nil)
      find_by(key: key)&.value || default
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      setting.value = value.to_s
      setting.save!
    end

    def recaptcha_score_threshold
      value = get(RECAPTCHA_SCORE_THRESHOLD)
      value.present? ? value.to_f : RECAPTCHA_SCORE_THRESHOLD_DEFAULT
    end

    def recaptcha_score_threshold=(value)
      set(RECAPTCHA_SCORE_THRESHOLD, value)
    end

    # Readonly Mode methods

    def readonly_mode_enabled?
      Rails.cache.fetch(CACHE_KEY_READONLY_MODE, expires_in: 1.minute) do
        enabled = get(READONLY_MODE_ENABLED) == "true"
        return false unless enabled

        expires_at = readonly_mode_expires_at
        if expires_at && expires_at <= Time.current
          disable_readonly_mode!
          false
        else
          true
        end
      end
    end

    def readonly_mode_expires_at
      value = get(READONLY_MODE_EXPIRES_AT)
      return nil if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def enable_readonly_mode!(expires_at: nil)
      transaction do
        set(READONLY_MODE_ENABLED, "true")
        if expires_at.present?
          set(READONLY_MODE_EXPIRES_AT, expires_at.iso8601)
          schedule_disable_job(expires_at)
        else
          set(READONLY_MODE_EXPIRES_AT, "")
        end
      end
      clear_readonly_mode_cache
      Rails.logger.info "[ReadonlyMode] Enabled. expires_at=#{expires_at&.iso8601 || 'none'}"
    end

    def disable_readonly_mode!
      transaction do
        set(READONLY_MODE_ENABLED, "false")
        set(READONLY_MODE_EXPIRES_AT, "")
      end
      clear_readonly_mode_cache
      Rails.logger.info "[ReadonlyMode] Disabled."
    end

    def clear_readonly_mode_cache
      Rails.cache.delete(CACHE_KEY_READONLY_MODE)
    end

    private

    def schedule_disable_job(expires_at)
      DisableReadonlyModeJob.set(wait_until: expires_at).perform_later
    end
  end
end
