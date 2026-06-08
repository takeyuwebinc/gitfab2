# frozen_string_literal: true

describe Card::Usage do
  it_behaves_like 'Card', :usage

  describe '#spam_author' do
    let(:usage) { FactoryBot.create(:usage) }

    context 'contribution があるとき' do
      let(:oldest) { FactoryBot.create(:user) }
      let(:newest) { FactoryBot.create(:user) }
      before do
        FactoryBot.create(:contribution, card: usage, contributor: newest, created_at: 1.hour.ago)
        FactoryBot.create(:contribution, card: usage, contributor: oldest, created_at: 2.hours.ago)
      end

      it '最古の contribution の contributor を返すこと' do
        expect(usage.spam_author).to eq oldest
      end
    end

    context 'contribution が無いとき' do
      it 'nil を返すこと' do
        expect(usage.spam_author).to be_nil
      end
    end
  end

  describe '#mark_spam!' do
    subject { usage.mark_spam! }
    let(:usage) { FactoryBot.create(:usage) }

    context '作成者を特定できるとき' do
      let(:author) { FactoryBot.create(:user) }
      let!(:notification) { FactoryBot.create(:notification, notifier: author) }
      before { FactoryBot.create(:contribution, card: usage, contributor: author, created_at: 1.hour.ago) }

      it '作成者の通知を削除してスパムとして記録すること' do
        expect { subject }.to change { usage.reload.status }.from('unconfirmed').to('spam')
        expect(Notification.exists?(notification.id)).to be false
      end

      it '作成者をスパム投稿者として登録すること' do
        expect { subject }.to change(Spammer, :count).by(1)
        expect(author.reload).to be_spammer
      end
    end

    context '作成者を特定できないとき（contribution 無し）' do
      it 'エラーにならず status のみ spam に変更すること' do
        expect { subject }.to change { usage.reload.status }.from('unconfirmed').to('spam')
      end

      it 'スパム投稿者を登録しないこと' do
        expect { subject }.not_to change(Spammer, :count)
      end
    end
  end

  describe '#unmark_spam!' do
    subject { usage.unmark_spam! }
    let(:usage) { FactoryBot.create(:usage, status: status) }

    context 'status が spam のとき' do
      let(:status) { 'spam' }
      it { expect { subject }.to change { usage.reload.status }.from('spam').to('unconfirmed') }
    end

    context 'status が approved のとき' do
      let(:status) { 'approved' }
      it { expect { subject }.to raise_error(RuntimeError, "Can't unmark spam approved comment") }
    end
  end
end
