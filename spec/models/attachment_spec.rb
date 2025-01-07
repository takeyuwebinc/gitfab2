# frozen_string_literal: true

describe Attachment do
  let(:attachment) do
    FactoryBot.build :attachment_material
  end

  describe '#dup_document' do
    subject { attachment.dup_document }
    it { expect(subject).to be_a(Attachment) }
    it { expect(subject).to_not eq(attachment) }
    it { expect(subject.title).to eq(attachment.title) }
    it { expect(subject.kind).to eq(attachment.kind) }
    it { expect(subject).to be_content_changed }
    describe 'content' do
      it { expect(subject.content.filename).to eq(attachment.content.filename) }
      it { expect(subject.content.file.size).to eq(attachment.content.file.size) }
      it { expect(subject.content.file.content_type).to eq(attachment.content.file.content_type) }
    end
  end

  context 'when attachment is an stl' do
    let(:attachment) do
      content = Rack::Test::UploadedFile.new(
        Rails.root.join('spec', 'fixtures', 'files', 'stls', 'cube-ascii.stl'),
        'model/stl'
      )
      build(:attachment, content:)
    end

    it "保存できること" do
      expect(attachment.save).to eq true
    end
  end
end
