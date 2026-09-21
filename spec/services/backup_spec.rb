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

  # MySQL は同じ position の行の順序を保証しない。手元の MySQL 8.0 では、position だけで
  # 並べると 17 枚以上で id の昇順以外の順に返るため、20 枚で確かめる。
  describe 'position が同じカードの並び' do
    let(:user) { create(:user) }
    let(:project) { create(:project, owner: user) }

    it 'State も Annotation も id の昇順に並ぶ' do
      states = Array.new(20) do |i|
        project.states.create!(title: "state #{i}", description: 'd').tap { |s| s.update_columns(position: i % 3) }
      end
      state = states.first
      annotations = Array.new(20) do |i|
        state.annotations.create!(title: "annotation #{i}").tap { |a| a.update_columns(position: i % 3) }
      end
      titles_in_order = ->(cards) { cards.map(&:reload).sort_by { |card| [card.position, card.id] }.map(&:title) }

      project_hash = Backup.new(user).send(:projects_hash).find { |hash| hash[:title] == project.title }
      backed_up_state = project_hash[:states].find { |hash| hash[:title] == state.title }

      aggregate_failures do
        expect(project_hash[:states].map { |hash| hash[:title] }).to eq titles_in_order.call(states)
        expect(backed_up_state[:annotations].map { |hash| hash[:title] }).to eq titles_in_order.call(annotations)
      end
    end
  end

  after(:each) do
    Backup.delete_old_files(Time.current)
  end
end
