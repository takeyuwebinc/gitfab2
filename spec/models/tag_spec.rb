# frozen_string_literal: true

describe Tag do
  it_behaves_like 'DraftInterfaceTest', FactoryBot.create(:tag)

  let(:tag) { FactoryBot.create(:tag) }

  it { expect(tag).to be_respond_to(:name) }

  describe '#user' do
    it { expect(tag).to be_respond_to(:user) }
    it { expect(tag.user).to be_an_instance_of(User) }
  end

  describe '#spam_author' do
    it 'user を返すこと' do
      expect(tag.spam_author).to eq tag.user
    end
  end

  describe '#mark_spam!' do
    subject { tag.mark_spam! }
    let(:author) { FactoryBot.create(:user) }
    let(:tag) { FactoryBot.create(:tag, user: author) }
    let!(:notification) { FactoryBot.create(:notification, notifier: author) }

    it '投稿者の通知を削除してスパムとして記録すること' do
      expect { subject }.to change { tag.reload.status }.from('unconfirmed').to('spam')
      expect(Notification.exists?(notification.id)).to be false
    end

    it '投稿者をスパム投稿者として登録すること' do
      expect { subject }.to change(Spammer, :count).by(1)
      expect(author.reload).to be_spammer
    end
  end

  describe '#unmark_spam!' do
    subject { tag.unmark_spam! }
    let(:tag) { FactoryBot.create(:tag, status: status) }

    context 'status が spam のとき' do
      let(:status) { 'spam' }
      it { expect { subject }.to change { tag.reload.status }.from('spam').to('unconfirmed') }
    end

    context 'status が approved のとき' do
      let(:status) { 'approved' }
      it { expect { subject }.to raise_error(RuntimeError, "Can't unmark spam approved comment") }
    end
  end
end
