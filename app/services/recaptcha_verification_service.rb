# frozen_string_literal: true

class RecaptchaVerificationService
  include Recaptcha::Adapters::ControllerMethods

  attr_reader :request, :error_message
  delegate :params, to: :request

  def initialize(request)
    @request = request
    @error_message = nil
  end

  def verify(action:)
    return success_result if skip_verification?

    unless token_present?
      @error_message = I18n.t("recaptcha.errors.token_missing")
      return failure_result
    end

    verify_token(action)
  end

  private

  def skip_verification?
    !recaptcha_configured?
  end

  def recaptcha_configured?
    Recaptcha.configuration.site_key.present? &&
      Recaptcha.configuration.secret_key.present?
  end

  def token_present?
    request.params.dig("g-recaptcha-response-data", "project").present?
  end

  def verify_token(action)
    threshold = SystemSetting.recaptcha_score_threshold

    success = verify_recaptcha(
      action: action,
      minimum_score: threshold,
      secret_key: Recaptcha.configuration.secret_key
    )

    log_score(success, threshold)

    if success
      success_result
    else
      @error_message = I18n.t("recaptcha.errors.verification_failed")
      failure_result
    end
  rescue StandardError => e
    Rails.logger.warn "[reCAPTCHA] API error: #{e.message}"
    success_result
  end

  def log_score(success, threshold)
    reply = recaptcha_reply
    return unless reply

    score = reply["score"]
    action = reply["action"]
    result = success ? "passed" : "blocked"

    Rails.logger.info "[reCAPTCHA] action=#{action} score=#{score} threshold=#{threshold} result=#{result}"
  end

  def success_result
    Result.new(success: true, error_message: nil)
  end

  def failure_result
    Result.new(success: false, error_message: @error_message)
  end

  Result = Struct.new(:success, :error_message, keyword_init: true) do
    def success?
      success
    end

    def failure?
      !success
    end
  end
end
