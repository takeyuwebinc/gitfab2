require 'spec_helper'

# スパム手動認定の状態遷移に伴う監査ログ記録のコールバック挙動を検証する。
RSpec.describe 'スパム認定の監査ログ記録', type: :model do
  let(:admin) { create(:administrator) }

  describe 'SpamMarkable#mark_spam! / #unmark_spam!' do
    let!(:comment) { create(:project_comment) }

    context '操作者が存在する場合' do
      before { Current.admin = admin }

      it 'mark_spam! で記録(marked)の監査ログを1組残す' do
        expect { comment.mark_spam! }
          .to change(AuditLog, :count).by(1)
          .and change(SpamModerationAudit, :count).by(1)

        audit = SpamModerationAudit.last
        expect(audit.action).to eq 'marked'
        expect(audit.target).to eq comment
        expect(audit.audit_log.operator).to eq admin
      end

      it 'unmark_spam! で取消(unmarked)の監査ログを残す' do
        comment.update!(status: :spam)
        AuditLog.delete_all
        SpamModerationAudit.delete_all

        expect { comment.unmark_spam! }.to change(AuditLog, :count).by(1)
        expect(SpamModerationAudit.last.action).to eq 'unmarked'
      end

      it 'approved→未確認(unapprove!)では記録しない' do
        comment.update!(status: :approved)
        AuditLog.delete_all
        SpamModerationAudit.delete_all

        expect { comment.unapprove! }.not_to change(AuditLog, :count)
      end
    end

    context '操作者が存在しない場合（Current.admin が nil）' do
      it '記録しない（自動スパム化の経路を兼ねる）' do
        expect { comment.mark_spam! }.not_to change(AuditLog, :count)
      end
    end
  end

  describe '一括スパム記録' do
    before { Current.admin = admin }

    it '対象ごとに1組ずつ記録する' do
      comments = create_list(:project_comment, 3)

      expect { comments.each(&:mark_spam!) }
        .to change(AuditLog, :count).by(3)
        .and change(SpamModerationAudit, :count).by(3)
    end
  end

  describe '記録失敗時の原子性' do
    let!(:comment) { create(:project_comment) }

    before { Current.admin = admin }

    it '監査ログのinsertが失敗すると状態変更もロールバックする' do
      allow(AuditLog).to receive(:create!).and_raise('audit insert failed')

      expect { comment.mark_spam! }.to raise_error('audit insert failed')
      expect(comment.reload).to be_unconfirmed
    end
  end

  describe 'Project#hide_as_spam! / #unhide_as_spam!' do
    let!(:project) { create(:project) }

    before { Current.admin = admin }

    it 'hide_as_spam! で記録(marked)を残す' do
      expect { project.hide_as_spam! }.to change(AuditLog, :count).by(1)

      audit = SpamModerationAudit.last
      expect(audit.action).to eq 'marked'
      expect(audit.target).to eq project
      expect(audit.audit_log.operator).to eq admin
    end

    it 'unhide_as_spam! で取消(unmarked)を残す' do
      project.hide_as_spam!
      AuditLog.delete_all
      SpamModerationAudit.delete_all

      expect { project.unhide_as_spam! }.to change(AuditLog, :count).by(1)
      expect(SpamModerationAudit.last.action).to eq 'unmarked'
    end

    it '操作者が存在しない場合は記録しない' do
      Current.admin = nil
      expect { project.hide_as_spam! }.not_to change(AuditLog, :count)
    end
  end
end
