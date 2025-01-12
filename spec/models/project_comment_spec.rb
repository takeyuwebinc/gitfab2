# frozen_string_literal: true

describe ProjectComment do
  describe "#manageable_by?" do
    subject { project_comment.manageable_by?(user) }
    let(:project_comment) { FactoryBot.create(:project_comment) }

    context "when user is a commenter" do
      let(:user) { project_comment.user }
      it { is_expected.to be true }
    end

    context "when user is not a commenter" do
      let(:user) { FactoryBot.create(:user) }

      context "and user is a project manager" do
        it do
          expect(project_comment.project).to receive(:manageable_by?).with(user).and_return(true)
          is_expected.to be true
        end
      end

      context "and user is a project manager" do
        it do
          expect(project_comment.project).to receive(:manageable_by?).with(user).and_return(false)
          is_expected.to be false
        end
      end
    end
  end

  describe '#approve!' do
    subject { project_comment.approve! }
    let(:project_comment) { create(:project_comment) }

    it do
      expect { subject }.to change { project_comment.reload.status }.from('unconfirmed').to('approved')
    end
  end

  describe '#unapprove!' do
    subject { project_comment.unapprove! }
    let(:project_comment) { create(:project_comment, status: status) }

    context 'when status is unconfirmed' do
      let(:status) { 'unconfirmed' }
      it do
        expect { subject }.not_to change { project_comment.reload.status }
      end
    end

    context 'when status is approved' do
      let(:status) { 'approved' }
      it do
        expect { subject }.to change { project_comment.reload.status }.from('approved').to('unconfirmed')
      end
    end

    context 'when status is spam' do
      let(:status) { 'spam' }
      it do
        expect { subject }.to raise_error(RuntimeError, "Can't unapprove spam comment")
      end
    end
  end

  describe '#mark_spam!' do
    subject { project_comment.mark_spam! }
    let(:comment_user) { create(:user) }
    let(:project_comment) { create(:project_comment, user: comment_user) }
    let!(:notification) { create(:notification, notifier: comment_user) }

    it "通知を削除してスパムとして記録すること" do
      expect { subject }.to change { project_comment.reload.status }.from('unconfirmed').to('spam')
      expect(Notification.exists?(notification.id)).to be false
    end

    context 'スパム投稿者として記録済みの場合' do
      before { create(:spammer, user: comment_user) }

      it { expect { subject }.to_not raise_error }
      it { expect { subject }.to_not change(Spammer, :count) }
    end

    context 'スパム投稿者として記録されていない場合' do
      it { expect { subject }.to_not raise_error }
      it { expect { subject }.to change(Spammer, :count).by(1) }
    end
  end

  describe '#unmark_spam!' do
    subject { project_comment.unmark_spam! }
    let(:project_comment) { create(:project_comment, status: status) }

    context 'when status is unconfirmed' do
      let(:status) { 'unconfirmed' }
      it do
        expect { subject }.not_to change { project_comment.reload.status }
      end
    end

    context 'when status is approved' do
      let(:status) { 'approved' }
      it do
        expect { subject }.to raise_error(RuntimeError, "Can't unmark spam approved comment")
      end
    end

    context 'when status is spam' do
      let(:status) { 'spam' }
      it do
        expect { subject }.to change { project_comment.reload.status }.from('spam').to('unconfirmed')
      end
    end
  end
end
