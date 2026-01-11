# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReadonlyModeRestriction, type: :controller do
  controller(ApplicationController) do
    include ReadonlyModeRestriction

    before_action :restrict_readonly_mode, only: [:restricted_action, :post_action]

    def restricted_action
      render plain: "OK"
    end

    def unrestricted_action
      render plain: "OK"
    end

    def post_action
      render plain: "Posted"
    end
  end

  before do
    routes.draw do
      get 'restricted_action' => 'anonymous#restricted_action'
      get 'unrestricted_action' => 'anonymous#unrestricted_action'
      post 'post_action' => 'anonymous#post_action'
    end
  end

  describe '#restrict_readonly_mode' do
    context 'when readonly mode is disabled' do
      before do
        allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(false)
      end

      it 'allows the action' do
        get :restricted_action
        expect(response.body).to eq("OK")
        expect(response).to have_http_status(:ok)
      end

      it 'does not log any rejection' do
        expect(Rails.logger).not_to receive(:warn).with(/\[ReadonlyMode\]/)
        get :restricted_action
      end
    end

    context 'when readonly mode is enabled' do
      before do
        allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
      end

      context 'with HTML request' do
        it 'redirects back with alert message' do
          request.env['HTTP_REFERER'] = 'http://test.host/previous'
          get :restricted_action
          expect(response).to redirect_to('http://test.host/previous')
          expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
        end

        it 'redirects to root when no referer' do
          get :restricted_action
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
        end

        it 'does not execute the action body' do
          expect(controller).not_to receive(:render).with(plain: "OK")
          get :restricted_action
        end
      end

      context 'with JSON request' do
        it 'returns 503 with error message' do
          get :restricted_action, format: :json
          expect(response).to have_http_status(:service_unavailable)
          json = JSON.parse(response.body)
          expect(json['success']).to eq(false)
          expect(json['error']).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
        end

        it 'returns proper content type' do
          get :restricted_action, format: :json
          expect(response.content_type).to include('application/json')
        end
      end

      context 'with POST request' do
        it 'redirects back for HTML' do
          request.env['HTTP_REFERER'] = 'http://test.host/form'
          post :post_action
          expect(response).to redirect_to('http://test.host/form')
          expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
        end

        it 'returns 503 for JSON' do
          post :post_action, format: :json
          expect(response).to have_http_status(:service_unavailable)
        end
      end

      describe 'logging' do
        let(:user) { create(:user) }

        it 'logs the rejection with anonymous user' do
          allow(Rails.logger).to receive(:warn).and_call_original
          expect(Rails.logger).to receive(:warn).with(/\[ReadonlyMode\] Request rejected: anonymous.*path=\/restricted_action/)
          get :restricted_action
        end

        it 'logs the rejection with logged in user' do
          sign_in user
          allow(Rails.logger).to receive(:warn).and_call_original
          expect(Rails.logger).to receive(:warn).with(/\[ReadonlyMode\] Request rejected: user_id=#{user.id}.*path=\/restricted_action/)
          get :restricted_action
        end

        it 'includes IP address in log' do
          allow(Rails.logger).to receive(:warn).and_call_original
          expect(Rails.logger).to receive(:warn).with(/ip=/)
          get :restricted_action
        end
      end
    end
  end

  describe 'unrestricted actions' do
    context 'when readonly mode is enabled' do
      before do
        allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
      end

      it 'allows unrestricted actions' do
        get :unrestricted_action
        expect(response.body).to eq("OK")
        expect(response).to have_http_status(:ok)
      end

      it 'does not show any error message' do
        get :unrestricted_action
        expect(flash[:alert]).to be_nil
      end
    end
  end

  describe 'READONLY_MODE_ERROR_MESSAGE constant' do
    it 'is in English' do
      expect(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE).to eq(
        "The site is currently in maintenance mode. Posting and editing are temporarily unavailable."
      )
    end
  end
end
