require 'spec_helper'

RSpec.describe SpamDesignationRevocationService do
  describe '.call' do
    context 'Userオーナーのプロジェクトの場合' do
      let(:user) { create(:user) }
      let(:project) { create(:project, owner: user) }

      before do
        create(:spammer, user: user)
        project.hide_as_spam!
      end

      it 'プロジェクトを再表示する' do
        expect { described_class.call(project) }.to change { project.reload.is_deleted }.from(true).to(false)
      end

      it 'spam_hidden_at を nil に戻す' do
        expect { described_class.call(project) }.to change { project.reload.spam_hidden_at }.to(nil)
      end

      it 'オーナーの Spammer 登録を解除する' do
        expect { described_class.call(project) }.to change { user.reload.spammer? }.from(true).to(false)
      end

      it '成功を返す' do
        expect(described_class.call(project)).to be true
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
        create(:spammer, user: member1)
        create(:spammer, user: member2)
        project.hide_as_spam!
      end

      it '取消時点の全メンバーの Spammer 登録を解除する' do
        expect { described_class.call(project) }
          .to change { member1.reload.spammer? }.from(true).to(false)
          .and change { member2.reload.spammer? }.from(true).to(false)
      end

      it 'プロジェクトを再表示する' do
        expect { described_class.call(project) }.to change { project.reload.is_deleted }.from(true).to(false)
      end
    end

    context '処理が失敗した場合' do
      let(:user) { create(:user) }
      let(:project) { create(:project, owner: user) }

      before do
        create(:spammer, user: user)
        project.hide_as_spam!
        allow(project).to receive(:unhide_as_spam!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'false を返し、Spammer 解除をロールバックする' do
        expect(described_class.call(project)).to be false
        expect(user.reload.spammer?).to be true
      end
    end
  end
end
