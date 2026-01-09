# frozen_string_literal: true

class SystemSetting < ApplicationRecord
  RECAPTCHA_SCORE_THRESHOLD = "recaptcha_score_threshold"
  RECAPTCHA_SCORE_THRESHOLD_DEFAULT = 0.5

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
  end
end
