# frozen_string_literal: true

# reCAPTCHA検証のテストヘルパー
# 実際の検証ロジックはrecaptcha gemのメソッドをスタブしてテスト
module RecaptchaHelper
  # reCAPTCHAが設定されている状態をスタブ
  def stub_recaptcha_configured
    allow(Recaptcha.configuration).to receive(:site_key).and_return("test_site_key")
    allow(Recaptcha.configuration).to receive(:secret_key).and_return("test_secret_key")
  end

  # recaptcha gemのverify_recaptchaメソッドをスタブして成功を返す
  def stub_recaptcha_verification_success
    stub_recaptcha_configured
    allow_any_instance_of(Recaptcha::Adapters::ControllerMethods)
      .to receive(:verify_recaptcha).and_return(true)
  end

  # recaptcha gemのverify_recaptchaメソッドをスタブして失敗を返す
  def stub_recaptcha_verification_failure
    stub_recaptcha_configured
    allow_any_instance_of(Recaptcha::Adapters::ControllerMethods)
      .to receive(:verify_recaptcha).and_return(false)
  end

  # API通信エラーをシミュレート（Timeout::Error）
  def stub_recaptcha_api_error
    stub_recaptcha_configured
    allow_any_instance_of(Recaptcha::Adapters::ControllerMethods)
      .to receive(:verify_recaptcha).and_raise(Timeout::Error)
  end
end

RSpec.configure do |config|
  config.include RecaptchaHelper
end
