# frozen_string_literal: true

describe RecaptchaVerificationService do
  let(:request) { instance_double(ActionDispatch::Request, params: params) }
  let(:service) { described_class.new(request) }
  let(:params) { { "g-recaptcha-response-data" => { "project" => "test_token" } } }

  describe "#verify" do
    context "when reCAPTCHA is not configured" do
      before do
        allow(Recaptcha.configuration).to receive(:site_key).and_return(nil)
        allow(Recaptcha.configuration).to receive(:secret_key).and_return(nil)
      end

      it "returns success (skips verification)" do
        result = service.verify(action: "project")
        expect(result).to be_success
      end
    end

    context "when reCAPTCHA is configured" do
      before { stub_recaptcha_configured }

      context "when token is missing" do
        let(:params) { {} }

        it "returns failure" do
          result = service.verify(action: "project")
          expect(result).to be_failure
        end

        it "sets error message" do
          result = service.verify(action: "project")
          expect(result.error_message).to eq I18n.t("recaptcha.errors.token_missing")
        end
      end

      context "when token is present" do
        context "and verification succeeds" do
          before { stub_recaptcha_verification_success }

          it "returns success" do
            result = service.verify(action: "project")
            expect(result).to be_success
          end
        end

        context "and verification fails" do
          before { stub_recaptcha_verification_failure }

          it "returns failure" do
            result = service.verify(action: "project")
            expect(result).to be_failure
          end

          it "sets error message" do
            result = service.verify(action: "project")
            expect(result.error_message).to eq I18n.t("recaptcha.errors.verification_failed")
          end
        end

        context "and API error occurs" do
          before { stub_recaptcha_api_error }

          it "returns success (fallback)" do
            result = service.verify(action: "project")
            expect(result).to be_success
          end
        end
      end
    end
  end
end
