# frozen_string_literal: true

RSpec.describe Admin::SystemSettingsController, type: :controller do
  let(:authority) { raise "Define authority in each context" }
  before { sign_in create(:user, authority: authority) }

  describe "GET #edit" do
    context "with authority" do
      let(:authority) { "admin" }

      it "returns a success response" do
        get :edit
        expect(response).to be_successful
      end

      it "assigns the current recaptcha_score_threshold" do
        SystemSetting.recaptcha_score_threshold = 0.7
        get :edit
        expect(assigns(:recaptcha_score_threshold)).to eq 0.7
      end
    end

    context "without authority" do
      let(:authority) { nil }

      it "redirects to the root path" do
        get :edit
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH #update" do
    context "with authority" do
      let(:authority) { "admin" }

      it "updates the recaptcha_score_threshold" do
        patch :update, params: { recaptcha_score_threshold: 0.8 }
        expect(SystemSetting.recaptcha_score_threshold).to eq 0.8
      end

      it "redirects to the edit page with notice" do
        patch :update, params: { recaptcha_score_threshold: 0.8 }
        expect(response).to redirect_to(edit_admin_system_settings_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "without authority" do
      let(:authority) { nil }

      it "redirects to the root path" do
        patch :update, params: { recaptcha_score_threshold: 0.8 }
        expect(response).to redirect_to(root_path)
      end

      it "does not update the setting" do
        original_value = SystemSetting.recaptcha_score_threshold
        patch :update, params: { recaptcha_score_threshold: 0.8 }
        expect(SystemSetting.recaptcha_score_threshold).to eq original_value
      end
    end
  end
end
