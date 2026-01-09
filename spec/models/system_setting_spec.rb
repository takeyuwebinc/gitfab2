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
end
