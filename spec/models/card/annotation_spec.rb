# frozen_string_literal: true

describe Card::Annotation do
  it_behaves_like 'Card', :annotation
  it_behaves_like 'Orderable', :annotation
  it_behaves_like 'Orderable Scoped incrementation', [:annotation], :state

  describe '.ordered_by_position' do
    let(:annotation) { FactoryBot.create(:annotation) }
    it { expect(Card::Annotation).to be_respond_to(:ordered_by_position) }
  end

  describe '.for_project' do
    let(:project) { FactoryBot.create(:user_project) }
    let!(:target) { FactoryBot.create(:annotation, state: FactoryBot.create(:state, :without_annotations, project: project)) }
    let!(:other) { FactoryBot.create(:annotation) }

    it 'state 経由で指定プロジェクトの annotation のみ返すこと' do
      expect(Card::Annotation.for_project(project.id)).to contain_exactly(target)
    end
  end

  describe '#spam_author' do
    let(:annotation) { FactoryBot.create(:annotation) }

    context 'contribution があるとき' do
      let(:oldest) { FactoryBot.create(:user) }
      let(:newest) { FactoryBot.create(:user) }
      before do
        FactoryBot.create(:contribution, card: annotation, contributor: newest, created_at: 1.hour.ago)
        FactoryBot.create(:contribution, card: annotation, contributor: oldest, created_at: 2.hours.ago)
      end

      it '最古の contribution の contributor を返すこと' do
        expect(annotation.spam_author).to eq oldest
      end
    end

    context 'contribution が無いとき' do
      it 'nil を返すこと' do
        expect(annotation.spam_author).to be_nil
      end
    end
  end

  describe '#mark_spam!' do
    subject { annotation.mark_spam! }
    let(:annotation) { FactoryBot.create(:annotation) }

    context '作成者を特定できるとき' do
      let(:author) { FactoryBot.create(:user) }
      let!(:notification) { FactoryBot.create(:notification, notifier: author) }
      before { FactoryBot.create(:contribution, card: annotation, contributor: author, created_at: 1.hour.ago) }

      it '作成者の通知を削除してスパムとして記録すること' do
        expect { subject }.to change { annotation.reload.status }.from('unconfirmed').to('spam')
        expect(Notification.exists?(notification.id)).to be false
      end

      it '作成者をスパム投稿者として登録すること' do
        expect { subject }.to change(Spammer, :count).by(1)
        expect(author.reload).to be_spammer
      end
    end

    context '作成者を特定できないとき（contribution 無し）' do
      it 'エラーにならず status のみ spam に変更すること' do
        expect { subject }.to change { annotation.reload.status }.from('unconfirmed').to('spam')
      end

      it 'スパム投稿者を登録しないこと' do
        expect { subject }.not_to change(Spammer, :count)
      end
    end
  end

  describe '#unmark_spam!' do
    subject { annotation.unmark_spam! }
    let(:annotation) { FactoryBot.create(:annotation, status: status) }

    context 'status が spam のとき' do
      let(:status) { 'spam' }

      it { expect { subject }.to change { annotation.reload.status }.from('spam').to('unconfirmed') }

      context '作成者を特定できるとき' do
        let(:author) { FactoryBot.create(:user) }
        before do
          FactoryBot.create(:contribution, card: annotation, contributor: author, created_at: 1.hour.ago)
          FactoryBot.create(:spammer, user: author)
        end

        it '作成者のスパム投稿者登録を解除すること' do
          expect { subject }.to change(Spammer, :count).by(-1)
        end

        it '作成者が spammer でなくなること' do
          subject
          expect(author.reload).not_to be_spammer
        end
      end

      context '作成者を特定できないとき（contribution 無し）' do
        it 'エラーにならず status のみ unconfirmed に戻すこと' do
          expect { subject }.to change { annotation.reload.status }.from('spam').to('unconfirmed')
        end

        it 'スパム投稿者登録を変更しないこと' do
          expect { subject }.not_to change(Spammer, :count)
        end
      end
    end

    context 'status が approved のとき' do
      let(:status) { 'approved' }
      it { expect { subject }.to raise_error(RuntimeError, "Can't unmark spam approved comment") }
    end
  end

  describe '#to_state!' do
    subject { annotation.to_state!(project) }

    let!(:project) { FactoryBot.create(:project) }
    let!(:parent_state) { FactoryBot.create(:state, :without_annotations, project: project) }
    let!(:annotation) { FactoryBot.create(:annotation, state: parent_state) }

    def stored(card)
      Card.unscoped.find(card.id)
    end

    # AnnotationsController#create と同じく、親 State の関連から組み立てて保存する。
    def add_annotation_to(state)
      Card::State.find(state.id).annotations.build(title: 'added', description: 'added').tap(&:save!)
    end

    it { is_expected.to be_an_instance_of(Card::State) }
    it do
      expect{ subject }.to change{ annotation.type }.from(Card::Annotation.name).to(Card::State.name)
                      .and change{ project.states_count }.by(1)
                      .and change{ Card::Annotation.count }.by(-1)
    end

    describe 'position' do
      before { FactoryBot.create_list(:state, state_count, project: project) }
      let(:state_count) { 2 }
      # プロジェクトの State は親 State と追加した state_count 個で、position の最大値は state_count + 1。
      it 'プロジェクトの State の position の最大値 + 1 になること' do
        expect(subject.position).to eq state_count + 2
      end
    end

    context '同じプロジェクトの State に属する Annotation を変換したとき' do
      before { FactoryBot.create_list(:state, 2, :without_annotations, project: project) }

      # プロジェクトの State は親 State と追加した 2 個で、position の最大値は 3。
      it 'state_id が NULL の State になり、position がプロジェクトの State の最大値 + 1 になること' do
        expect { subject }.to change { project.reload.states_count }.by(1)
        expect(stored(annotation).attributes.slice('type', 'state_id', 'position'))
          .to eq('type' => Card::State.name, 'state_id' => nil, 'position' => 4)
      end
    end

    context '変換先の position が親に残る Annotation の position を上回るとき' do
      # State 4 個・Annotation 3 件。変換先の position 5 は、親に残る Annotation のどれよりも大きい。
      before do
        FactoryBot.create_list(:state, 3, :without_annotations, project: project)
        FactoryBot.create_list(:annotation, 2, state: parent_state)
      end

      it '元の親 State に追加した Annotation が、親に残る Annotation の最大値 + 1 の position で保存されること' do
        subject
        remaining_max = Card::Annotation.where(state_id: parent_state.id).maximum(:position)
        expect(stored(annotation).position).to be > remaining_max
        added = add_annotation_to(parent_state)
        expect(stored(added).attributes.slice('type', 'state_id', 'position'))
          .to eq('type' => Card::Annotation.name, 'state_id' => parent_state.id, 'position' => remaining_max + 1)
      end
    end

    context '変換先の position が親に残る Annotation の position の最大値を下回るとき' do
      # State 2 個・Annotation 4 件。position 1 の Annotation を変換すると、変換先の position は 3 で、
      # 親に残る Annotation の position 4 を下回る。
      let!(:rest) do
        FactoryBot.create(:state, :without_annotations, project: project)
        FactoryBot.create_list(:annotation, 3, state: parent_state)
      end

      it '親の並びへの追加と削除が、変換した State の position と updated_at を動かさないこと' do
        subject
        Card.unscoped.where(id: annotation.id).update_all(updated_at: Time.zone.parse('2026-01-01 00:00:00'))
        converted = stored(annotation).attributes.slice('type', 'position', 'updated_at')
        remaining_max = Card::Annotation.where(state_id: parent_state.id).maximum(:position)
        expect(converted['position']).to be < remaining_max

        added = add_annotation_to(parent_state)
        expect(stored(added).position).to eq remaining_max + 1
        Card::Annotation.find(rest.first.id).destroy

        expect(stored(annotation).attributes.slice('type', 'position', 'updated_at')).to eq converted
      end
    end

    context '変換元の親 State の並びに属さないカード' do
      # 変換先の position（3）以上の position を持つ State を別プロジェクトに置き、state_id が NULL の
      # カード全体の position が動いた場合に検出できるようにする。
      let!(:other_state) { FactoryBot.create(:state, project: project, annotations_count: 2) }
      let!(:other_project) { FactoryBot.create(:project) }
      before { FactoryBot.create_list(:state, 4, project: other_project, annotations_count: 1) }

      it 'position が変わらないこと' do
        list_ids = Card.unscoped.where(state_id: parent_state.id).pluck(:id)
        outside = Card.unscoped.where.not(id: list_ids).order(:id)
        expect(outside.where(type: Card::State.name, project_id: other_project.id).maximum(:position)).to be >= 3
        expect { subject }.not_to change { outside.pluck(:id, :position) }
      end
    end

    context 'タイトルと本文の両方が空の Annotation を変換したとき' do
      before { annotation.update_columns(title: nil, description: nil) }

      it '検証の例外を送出し、行の type・state_id・position とプロジェクトの states_count を変えないこと' do
        before_row = stored(annotation).attributes.slice('type', 'state_id', 'position')
        expect {
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
        }.not_to change { project.reload.states_count }
        expect(stored(annotation).attributes.slice('type', 'state_id', 'position')).to eq before_row
      end
    end

    context '親 State の Annotation が変換する 1 件だけのとき' do
      it '変換後に親へ追加した Annotation の position が 1 になること' do
        subject
        expect(stored(add_annotation_to(parent_state)).position).to eq 1
      end
    end
  end
end
