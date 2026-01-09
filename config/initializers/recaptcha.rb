# frozen_string_literal: true

Recaptcha.configure do |config|
  # 環境変数優先、なければCredentials
  config.site_key = ENV["RECAPTCHA_SITE_KEY"] ||
                    Rails.application.credentials.dig(:recaptcha, :site_key)
  config.secret_key = ENV["RECAPTCHA_SECRET_KEY"] ||
                      Rails.application.credentials.dig(:recaptcha, :secret_key)
end
