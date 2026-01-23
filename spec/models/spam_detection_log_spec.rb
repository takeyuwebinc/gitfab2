RSpec.describe SpamDetectionLog, type: :model do
  describe "バリデーション" do
    let(:user) { create(:user) }

    it "有効なデータで作成できること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: "192.168.1.1",
        detection_method: "keyword",
        content_type: "Project"
      )
      expect(log).to be_valid
    end

    it "ユーザーが必須であること" do
      log = SpamDetectionLog.new(
        user: nil,
        ip_address: "192.168.1.1",
        detection_method: "keyword",
        content_type: "Project"
      )
      expect(log).not_to be_valid
      expect(log.errors[:user]).to be_present
    end

    it "IPアドレスが必須であること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: nil,
        detection_method: "keyword",
        content_type: "Project"
      )
      expect(log).not_to be_valid
      expect(log.errors[:ip_address]).to include("can't be blank")
    end

    it "検出方法が必須であること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: "192.168.1.1",
        detection_method: nil,
        content_type: "Project"
      )
      expect(log).not_to be_valid
      expect(log.errors[:detection_method]).to include("can't be blank")
    end

    it "検出方法がkeyword, spammer, recaptchaのいずれかであること" do
      %w[keyword spammer recaptcha].each do |method|
        log = SpamDetectionLog.new(
          user: user,
          ip_address: "192.168.1.1",
          detection_method: method,
          content_type: "Project"
        )
        expect(log).to be_valid
      end
    end

    it "不正な検出方法は無効であること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: "192.168.1.1",
        detection_method: "invalid_method",
        content_type: "Project"
      )
      expect(log).not_to be_valid
      expect(log.errors[:detection_method]).to include("is not included in the list")
    end

    it "コンテンツ種別が必須であること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: "192.168.1.1",
        detection_method: "keyword",
        content_type: nil
      )
      expect(log).not_to be_valid
      expect(log.errors[:content_type]).to include("can't be blank")
    end

    it "検出理由はオプションであること" do
      log = SpamDetectionLog.new(
        user: user,
        ip_address: "192.168.1.1",
        detection_method: "keyword",
        content_type: "Project",
        detection_reason: nil
      )
      expect(log).to be_valid
    end
  end

  describe "スコープ" do
    describe ".recent" do
      it "作成日時の降順で返すこと" do
        old_log = create(:spam_detection_log, created_at: 1.day.ago)
        new_log = create(:spam_detection_log, created_at: 1.hour.ago)

        expect(SpamDetectionLog.recent).to eq([new_log, old_log])
      end
    end
  end
end
