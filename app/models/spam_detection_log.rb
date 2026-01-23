class SpamDetectionLog < ApplicationRecord
  DETECTION_METHODS = %w[keyword spammer recaptcha].freeze

  belongs_to :user

  validates :ip_address, presence: true
  validates :detection_method, presence: true, inclusion: { in: DETECTION_METHODS }
  validates :content_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
