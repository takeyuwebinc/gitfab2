# frozen_string_literal: true

require "spec_helper"

RSpec.describe DisableReadonlyModeJob do
  describe "#perform" do
    before do
      SystemSetting.clear_readonly_mode_cache
    end

    after do
      SystemSetting.clear_readonly_mode_cache
    end

    context "when readonly mode is not enabled" do
      it "does not call disable_readonly_mode!" do
        expect(SystemSetting).not_to receive(:disable_readonly_mode!)
        described_class.new.perform
      end

      it "logs that readonly mode is already disabled" do
        expect(Rails.logger).to receive(:info).with("[DisableReadonlyModeJob] Readonly mode already disabled, skipping.")
        described_class.new.perform
      end
    end

    context "when readonly mode is enabled without expires_at" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.clear_readonly_mode_cache
      end

      it "does not call disable_readonly_mode!" do
        expect(SystemSetting).not_to receive(:disable_readonly_mode!)
        described_class.new.perform
      end

      it "logs that expires_at is not set" do
        expect(Rails.logger).to receive(:info).with("[DisableReadonlyModeJob] Readonly mode expires_at not reached or cleared, skipping.")
        described_class.new.perform
      end

      it "keeps readonly mode enabled" do
        described_class.new.perform
        SystemSetting.clear_readonly_mode_cache
        expect(SystemSetting.readonly_mode_enabled?).to be true
      end
    end

    context "when readonly mode is enabled with future expires_at" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, 1.hour.from_now.iso8601)
        SystemSetting.clear_readonly_mode_cache
      end

      it "does not call disable_readonly_mode!" do
        expect(SystemSetting).not_to receive(:disable_readonly_mode!)
        described_class.new.perform
      end

      it "logs that expires_at is not reached" do
        expect(Rails.logger).to receive(:info).with("[DisableReadonlyModeJob] Readonly mode expires_at not reached or cleared, skipping.")
        described_class.new.perform
      end

      it "keeps readonly mode enabled" do
        described_class.new.perform
        SystemSetting.clear_readonly_mode_cache
        expect(SystemSetting.readonly_mode_enabled?).to be true
      end
    end

    context "when readonly mode is enabled with expired expires_at" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, 1.hour.ago.iso8601)
        SystemSetting.clear_readonly_mode_cache
      end

      it "disables readonly mode" do
        described_class.new.perform
        SystemSetting.clear_readonly_mode_cache
        expect(SystemSetting.readonly_mode_enabled?).to be false
      end

      it "clears expires_at" do
        described_class.new.perform
        expect(SystemSetting.readonly_mode_expires_at).to be_nil
      end

      it "eventually results in readonly mode being disabled (either by job or cache check)" do
        # Note: readonly_mode_enabled? also auto-disables when expired
        # So the job may find it already disabled, which is the intended behavior
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.new.perform
        expect(SystemSetting.get(SystemSetting::READONLY_MODE_ENABLED)).to eq("false")
      end
    end

    context "when readonly mode is enabled with expires_at exactly at current time" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, Time.current.iso8601)
        SystemSetting.clear_readonly_mode_cache
      end

      it "disables readonly mode" do
        described_class.new.perform
        SystemSetting.clear_readonly_mode_cache
        expect(SystemSetting.readonly_mode_enabled?).to be false
      end
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
