# frozen_string_literal: true

describe SystemSetting do
  describe "validations" do
    describe "key" do
      it "requires key to be present" do
        setting = SystemSetting.new(key: nil, value: "test")
        expect(setting).not_to be_valid
        expect(setting.errors[:key]).to include("can't be blank")
      end

      it "requires key to be unique" do
        SystemSetting.create!(key: "unique_key", value: "test")
        duplicate = SystemSetting.new(key: "unique_key", value: "other")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:key]).to include("has already been taken")
      end
    end
  end

  describe ".get" do
    context "when setting exists" do
      before { SystemSetting.create!(key: "test_key", value: "test_value") }

      it "returns the value" do
        expect(SystemSetting.get("test_key")).to eq "test_value"
      end
    end

    context "when setting does not exist" do
      it "returns nil" do
        expect(SystemSetting.get("nonexistent_key")).to be_nil
      end

      it "returns default value if provided" do
        expect(SystemSetting.get("nonexistent_key", default: "default")).to eq "default"
      end
    end
  end

  describe ".set" do
    context "when setting does not exist" do
      it "creates a new setting" do
        expect { SystemSetting.set("new_key", "new_value") }
          .to change(SystemSetting, :count).by(1)
      end

      it "stores the value" do
        SystemSetting.set("new_key", "new_value")
        expect(SystemSetting.get("new_key")).to eq "new_value"
      end
    end

    context "when setting already exists" do
      before { SystemSetting.create!(key: "existing_key", value: "old_value") }

      it "updates the value" do
        SystemSetting.set("existing_key", "new_value")
        expect(SystemSetting.get("existing_key")).to eq "new_value"
      end

      it "does not create a new record" do
        expect { SystemSetting.set("existing_key", "new_value") }
          .not_to change(SystemSetting, :count)
      end
    end
  end

  describe ".recaptcha_score_threshold" do
    context "when not set" do
      it "returns the default value" do
        expect(SystemSetting.recaptcha_score_threshold).to eq 0.5
      end
    end

    context "when set" do
      before { SystemSetting.set(SystemSetting::RECAPTCHA_SCORE_THRESHOLD, "0.7") }

      it "returns the configured value" do
        expect(SystemSetting.recaptcha_score_threshold).to eq 0.7
      end
    end
  end

  describe ".recaptcha_score_threshold=" do
    it "stores the value" do
      SystemSetting.recaptcha_score_threshold = 0.8
      expect(SystemSetting.recaptcha_score_threshold).to eq 0.8
    end
  end

  describe ".readonly_mode_enabled?" do
    before do
      SystemSetting.clear_readonly_mode_cache
    end

    context "when not set" do
      it "returns false" do
        expect(SystemSetting.readonly_mode_enabled?).to be false
      end
    end

    context "when enabled" do
      before { SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true") }

      it "returns true" do
        expect(SystemSetting.readonly_mode_enabled?).to be true
      end
    end

    context "when disabled" do
      before { SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "false") }

      it "returns false" do
        expect(SystemSetting.readonly_mode_enabled?).to be false
      end
    end

    context "when enabled with expired expires_at" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, 1.hour.ago.iso8601)
      end

      it "returns false and disables the mode" do
        expect(SystemSetting.readonly_mode_enabled?).to be false
        expect(SystemSetting.get(SystemSetting::READONLY_MODE_ENABLED)).to eq "false"
      end
    end

    context "when enabled with future expires_at" do
      before do
        SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
        SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, 1.hour.from_now.iso8601)
      end

      it "returns true" do
        expect(SystemSetting.readonly_mode_enabled?).to be true
      end
    end
  end

  describe ".readonly_mode_expires_at" do
    context "when not set" do
      it "returns nil" do
        expect(SystemSetting.readonly_mode_expires_at).to be_nil
      end
    end

    context "when set with valid datetime" do
      let(:expires_at) { 1.hour.from_now.change(usec: 0) }

      before { SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, expires_at.iso8601) }

      it "returns the datetime" do
        expect(SystemSetting.readonly_mode_expires_at).to eq expires_at
      end
    end

    context "when set with invalid value" do
      before { SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, "invalid") }

      it "returns nil" do
        expect(SystemSetting.readonly_mode_expires_at).to be_nil
      end
    end
  end

  describe ".enable_readonly_mode!" do
    before do
      SystemSetting.clear_readonly_mode_cache
      allow(DisableReadonlyModeJob).to receive_message_chain(:set, :perform_later)
    end

    context "without expires_at" do
      it "enables readonly mode" do
        SystemSetting.enable_readonly_mode!
        expect(SystemSetting.readonly_mode_enabled?).to be true
      end

      it "does not schedule a job" do
        SystemSetting.enable_readonly_mode!
        expect(DisableReadonlyModeJob).not_to have_received(:set)
      end
    end

    context "with expires_at" do
      let(:expires_at) { 1.hour.from_now }

      it "enables readonly mode with expires_at" do
        SystemSetting.enable_readonly_mode!(expires_at: expires_at)
        expect(SystemSetting.readonly_mode_enabled?).to be true
        expect(SystemSetting.readonly_mode_expires_at).to be_within(1.second).of(expires_at)
      end

      it "schedules the disable job" do
        job_double = double
        allow(DisableReadonlyModeJob).to receive(:set).with(wait_until: expires_at).and_return(job_double)
        allow(job_double).to receive(:perform_later)

        SystemSetting.enable_readonly_mode!(expires_at: expires_at)

        expect(DisableReadonlyModeJob).to have_received(:set).with(wait_until: expires_at)
        expect(job_double).to have_received(:perform_later)
      end
    end
  end

  describe ".disable_readonly_mode!" do
    before do
      SystemSetting.set(SystemSetting::READONLY_MODE_ENABLED, "true")
      SystemSetting.set(SystemSetting::READONLY_MODE_EXPIRES_AT, 1.hour.from_now.iso8601)
      SystemSetting.clear_readonly_mode_cache
    end

    it "disables readonly mode" do
      SystemSetting.disable_readonly_mode!
      expect(SystemSetting.readonly_mode_enabled?).to be false
    end

    it "clears expires_at" do
      SystemSetting.disable_readonly_mode!
      expect(SystemSetting.readonly_mode_expires_at).to be_nil
    end

    it "clears the cache" do
      expect(Rails.cache).to receive(:delete).with(SystemSetting::CACHE_KEY_READONLY_MODE)
      SystemSetting.disable_readonly_mode!
    end

    it "logs the action" do
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with("[ReadonlyMode] Disabled.")
      SystemSetting.disable_readonly_mode!
    end
  end

  describe ".clear_readonly_mode_cache" do
    it "deletes the cache key" do
      expect(Rails.cache).to receive(:delete).with(SystemSetting::CACHE_KEY_READONLY_MODE)
      SystemSetting.clear_readonly_mode_cache
    end
  end

  describe "cache behavior" do
    before do
      SystemSetting.clear_readonly_mode_cache
    end

    it "uses Rails.cache.fetch for readonly_mode_enabled?" do
      expect(Rails.cache).to receive(:fetch)
        .with(SystemSetting::CACHE_KEY_READONLY_MODE, expires_in: 1.minute)
        .and_call_original
      SystemSetting.readonly_mode_enabled?
    end
  end

  describe "constants" do
    it "defines READONLY_MODE_ENABLED key" do
      expect(SystemSetting::READONLY_MODE_ENABLED).to eq("readonly_mode_enabled")
    end

    it "defines READONLY_MODE_EXPIRES_AT key" do
      expect(SystemSetting::READONLY_MODE_EXPIRES_AT).to eq("readonly_mode_expires_at")
    end

    it "defines CACHE_KEY_READONLY_MODE" do
      expect(SystemSetting::CACHE_KEY_READONLY_MODE).to eq("system_setting:readonly_mode")
    end
  end
end
