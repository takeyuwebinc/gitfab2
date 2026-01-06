require 'spec_helper'

RSpec.describe SpamDesignationService do
  describe '.call' do
    context 'Userオーナーのプロジェクトの場合' do
      let(:user) { create(:user) }
      let(:project) { create(:project, owner: user) }

      it 'オーナーをSpammerとして登録する' do
        expect { described_class.call([project]) }.to change { user.reload.spammer? }.from(false).to(true)
      end

      it 'プロジェクトを論理削除する' do
        expect { described_class.call([project]) }.to change { project.reload.is_deleted }.from(false).to(true)
      end

      it '成功件数を返す' do
        result = described_class.call([project])
        expect(result.success).to eq 1
        expect(result.failed).to be_empty
      end
    end

    context 'Groupオーナーのプロジェクトの場合' do
      let(:group) { create(:group) }
      let(:member1) { create(:user) }
      let(:member2) { create(:user) }
      let(:project) { create(:project, owner: group) }

      before do
        create(:membership, group: group, user: member1)
        create(:membership, group: group, user: member2)
      end

      it 'グループの全メンバーをSpammerとして登録する' do
        expect { described_class.call([project]) }
          .to change { member1.reload.spammer? }.from(false).to(true)
          .and change { member2.reload.spammer? }.from(false).to(true)
      end

      it 'プロジェクトを論理削除する' do
        expect { described_class.call([project]) }.to change { project.reload.is_deleted }.from(false).to(true)
      end
    end

    context '複数プロジェクトの一括処理' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:project1) { create(:project, owner: user1) }
      let(:project2) { create(:project, owner: user2) }

      it 'すべてのプロジェクトを処理する' do
        result = described_class.call([project1, project2])

        expect(result.success).to eq 2
        expect(result.failed).to be_empty
        expect(project1.reload.is_deleted).to be true
        expect(project2.reload.is_deleted).to be true
        expect(user1.reload.spammer?).to be true
        expect(user2.reload.spammer?).to be true
      end
    end

    context '既にSpammerとして登録済みのユーザーの場合' do
      let(:user) { create(:user) }
      let(:project) { create(:project, owner: user) }

      before { create(:spammer, user: user) }

      it 'エラーにならず処理を継続する' do
        result = described_class.call([project])
        expect(result.success).to eq 1
        expect(result.failed).to be_empty
      end
    end

    context '一部のプロジェクトで処理が失敗した場合' do
      let(:user) { create(:user) }
      let(:project1) { create(:project, owner: user) }
      let(:project2) { create(:project, owner: user) }

      before do
        allow(project2).to receive(:soft_destroy!).and_raise(ActiveRecord::RecordInvalid)
      end

      it '失敗したプロジェクトも残りのプロジェクトも正しく報告する' do
        result = described_class.call([project1, project2])

        expect(result.success).to eq 1
        expect(result.failed).to include(project2)
        expect(project1.reload.is_deleted).to be true
      end
    end
  end
end
