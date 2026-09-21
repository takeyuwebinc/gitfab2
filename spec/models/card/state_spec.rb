# frozen_string_literal: true

describe Card::State do
  it_behaves_like 'Card', :state
  it_behaves_like 'Orderable', :state
  it_behaves_like 'Orderable Scoped incrementation', [:state], :project

  describe '.ordered_by_position' do
    let(:state) { FactoryBot.build :state }
    it { expect(Card::State).to be_respond_to(:ordered_by_position) }
  end

  describe '#to_annotation!' do
    subject { state.to_annotation!(parent_state) }

    let(:project) { FactoryBot.create(:project) }
    let(:state) { FactoryBot.create(:state, project: project) }
    let(:parent_state) { FactoryBot.create(:state, project: project) }

    before do
      state
      parent_state
    end

    shared_examples '変換先を拒否すること' do
      it '例外を送出すること' do
        expect { subject }.to raise_error(Card::State::InvalidConversionTarget)
      end

      it 'type・state_id・position が変わらないこと' do
        expect {
          expect { subject }.to raise_error(Card::State::InvalidConversionTarget)
        }.to_not change { state.reload.attributes.slice('type', 'state_id', 'position') }
      end

      it 'プロジェクトの states_count が変わらないこと' do
        expect {
          expect { subject }.to raise_error(Card::State::InvalidConversionTarget)
        }.to_not change { project.reload.states_count }
      end

      it '変換先プロジェクトの states_count が変わらないこと' do
        expect {
          expect { subject }.to raise_error(Card::State::InvalidConversionTarget)
        }.to_not change { parent_state.project.reload.states_count }
      end
    end

    it { is_expected.to be_an_instance_of(Card::Annotation) }
    it do
      expect{ subject }.to change{ state.type }.from(Card::State.name).to(Card::Annotation.name)
                      .and change{ parent_state.annotations.count }.by(1)
                      .and change{ project.reload.states_count }.by(-1)
    end

    it '変換後の Annotation の state_id が変換先の State の id になること' do
      subject
      expect(Card.unscoped.find(state.id).state_id).to eq parent_state.id
    end

    context '変換先が変換元自身の場合' do
      let(:parent_state) { state }

      include_examples '変換先を拒否すること'
    end

    context '変換先が別プロジェクトの State の場合' do
      let(:parent_state) { FactoryBot.create(:state) }

      include_examples '変換先を拒否すること'
    end
  end

  describe '#dup_document' do
    subject(:dupped_card) do
      card.dup_document.tap(&:save!)
    end

    let(:card) do
      FactoryBot.create(:state, annotations_count: annotation_count)
    end
    let(:annotation_count) { 5 }

    it '数を維持すること' do
      expect(dupped_card.annotations.count).to eq(annotation_count)
    end
    it '順番・内容を維持すること' do
      card.annotations.to_a.shuffle.each.with_index(1) do |annotation, i|
        annotation.update_column(:position, i)
      end
      card.annotations.reload

      actual   = Card::Annotation.where(id: dupped_card.annotations.pluck(:id)).order(:position).map(&:title)
      expected = Card::Annotation.where(id: card       .annotations.pluck(:id)).order(:position).map(&:title)
      expect(actual).to eq(expected)
    end
    it '複製であること' do
      expect(dupped_card.annotations.map(&:id)).to_not eq(card.annotations.map(&:id))
    end
  end
end
