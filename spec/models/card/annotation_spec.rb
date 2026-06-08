# frozen_string_literal: true

describe Card::Annotation do
  it_behaves_like 'Card', :annotation
  it_behaves_like 'Orderable', :annotation
  it_behaves_like 'Orderable Scoped incrementation', [:annotation], :state

  describe '.ordered_by_position' do
    let(:annotation) { FactoryBot.create(:annotation) }
    it { expect(Card::Annotation).to be_respond_to(:ordered_by_position) }
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

    let!(:annotation) { FactoryBot.create(:annotation) }
    let!(:project) { FactoryBot.create(:project) }

    it { is_expected.to be_an_instance_of(Card::State) }
    it do
      expect{ subject }.to change{ annotation.type }.from(Card::Annotation.name).to(Card::State.name)
                      .and change{ project.states_count }.by(1)
                      .and change{ Card::Annotation.count }.by(-1)
    end

    describe 'position' do
      before { FactoryBot.create_list(:state, state_count, project: project) }
      let(:state_count) { 2 }
      it { expect(subject.position).to eq state_count + 1 }
    end
  end
end
