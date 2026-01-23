RSpec.describe SpamDetectionLogRecorder do
  describe ".record" do
    let(:user) { create(:user) }
    let(:ip_address) { "192.168.1.1" }
    let(:detection_method) { "keyword" }
    let(:content_type) { "Project" }
    let(:detection_reason) { "spam_keyword" }

    it "creates a spam detection log" do
      expect {
        SpamDetectionLogRecorder.record(
          user: user,
          ip_address: ip_address,
          detection_method: detection_method,
          content_type: content_type,
          detection_reason: detection_reason
        )
      }.to change(SpamDetectionLog, :count).by(1)

      log = SpamDetectionLog.last
      expect(log.user).to eq(user)
      expect(log.ip_address).to eq(ip_address)
      expect(log.detection_method).to eq(detection_method)
      expect(log.content_type).to eq(content_type)
      expect(log.detection_reason).to eq(detection_reason)
    end

    it "creates a log without detection_reason" do
      log = SpamDetectionLogRecorder.record(
        user: user,
        ip_address: ip_address,
        detection_method: "spammer",
        content_type: content_type
      )

      expect(log.detection_reason).to be_nil
    end

    context "when an error occurs" do
      it "returns nil and logs the error" do
        allow(SpamDetectionLog).to receive(:create!).and_raise(StandardError.new("DB error"))

        expect(Rails.logger).to receive(:error).with(/Failed to record log/)

        result = SpamDetectionLogRecorder.record(
          user: user,
          ip_address: ip_address,
          detection_method: detection_method,
          content_type: content_type
        )

        expect(result).to be_nil
      end
    end
  end
end
