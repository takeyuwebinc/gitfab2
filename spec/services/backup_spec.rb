# frozen_string_literal: true

describe Backup do
  describe '.delete_old_files' do
    subject { zip_path.exist? }
    let(:zip_path) { Rails.root.join('tmp', 'backup', 'zip', 'example.zip') }

    before do
      Rails.root.join('tmp', 'backup', 'zip').mkpath
      File.open(zip_path, 'w')
      File.utime(3.days.ago.to_time, 3.days.ago.to_time, zip_path)
    end

    context 'when passing no arg (default: 3.days.ago)' do
      before { Backup.delete_old_files }
      it { is_expected.to eq false }
    end

    context 'when passing 4.days.ago' do
      before { Backup.delete_old_files(4.day.ago) }
      it { is_expected.to eq true }
    end
  end

  describe '#create' do
    it "バックアップを作成すること" do
      user = create(:user)
      backup = Backup.new(user)
      expect { backup.create }.to change { backup.zip_exist? }.from(false).to(true)
    end
  end

  after(:each) do
    Backup.delete_old_files(Time.current)
  end
end
