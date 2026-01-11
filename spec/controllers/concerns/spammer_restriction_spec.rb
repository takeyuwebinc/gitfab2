# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpammerRestriction, type: :controller do
  controller(ApplicationController) do
    include SpammerRestriction

    def test_action
      if spammer_silent_reject?("test_action")
        redirect_to spammer_redirect_path
        return
      end

      render plain: "OK"
    end
  end

  before do
    routes.draw { get 'test_action' => 'anonymous#test_action' }
  end

  describe '#spammer_silent_reject?' do
    context 'when user is not logged in' do
      it 'returns false' do
        get :test_action
        expect(response.body).to eq("OK")
      end
    end

    context 'when user is logged in' do
      let(:user) { create(:user) }

      before { sign_in user }

      context 'and user is not a spammer' do
        it 'returns false and allows the action' do
          get :test_action
          expect(response.body).to eq("OK")
        end
      end

      context 'and user is a spammer' do
        before { create(:spammer, user: user) }

        it 'returns true and redirects to owner page' do
          get :test_action
          expect(response).to redirect_to(owner_path(owner_name: user.slug))
        end

        it 'logs the silent rejection' do
          allow(Rails.logger).to receive(:info).and_call_original
          expect(Rails.logger).to receive(:info).with("[SpammerRestriction] Silent rejection: user_id=#{user.id}, action=test_action").and_call_original
          get :test_action
        end
      end
    end
  end

  describe '#spammer_redirect_path' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'returns the owner path for current user' do
      get :test_action
      # The redirect path is tested indirectly through the redirect in spammer case
      expect(controller.send(:spammer_redirect_path)).to eq(owner_path(user))
    end
  end
end
