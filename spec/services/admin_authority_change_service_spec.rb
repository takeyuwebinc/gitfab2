require 'spec_helper'

RSpec.describe AdminAuthorityChangeService do
  let(:operator) { create(:administrator) }

  before do
    Current.admin = operator
    Current.ip_address = '198.51.100.7'
  end

  describe '.grant' do
    context '対象が一般ユーザーの場合' do
      let(:target) { create(:user) }

      it '管理者権限を付与し成功する' do
        result = described_class.grant(target_user: target, operator: operator)

        expect(result.success?).to be true
        expect(result.changed).to be true
        expect(target.reload).to be_is_system_admin
      end

      it '付与(grant)の監査ログを操作者・IP 付きで1組残す' do
        expect { described_class.grant(target_user: target, operator: operator) }
          .to change(AuditLog, :count).by(1)
          .and change(AdminAuthorityAudit, :count).by(1)

        audit = AdminAuthorityAudit.last
        expect(audit.action).to eq 'grant'
        expect(audit.target_user).to eq target
        expect(audit.audit_log.operator).to eq operator
        expect(audit.audit_log.ip_address).to eq '198.51.100.7'
      end
    end

    context '対象が既に管理者の場合（冪等）' do
      let(:target) { create(:administrator) }

      it '状態を変えず成功扱いとし、監査記録もしない' do
        result = nil
        expect { result = described_class.grant(target_user: target, operator: operator) }
          .not_to change(AuditLog, :count)

        expect(result.success?).to be true
        expect(result.changed).to be false
        expect(target.reload).to be_is_system_admin
      end
    end
  end

  describe '.revoke' do
    context '対象が他の管理者で、剥奪後も管理者が残る場合' do
      let!(:target) { create(:administrator) }

      it '管理者権限を剥奪し成功する' do
        result = described_class.revoke(target_user: target, operator: operator)

        expect(result.success?).to be true
        expect(result.changed).to be true
        expect(target.reload).not_to be_is_system_admin
        expect(target.reload.authority).to be_nil
      end

      it '剥奪(revoke)の監査ログを1組残す' do
        expect { described_class.revoke(target_user: target, operator: operator) }
          .to change(AuditLog, :count).by(1)
          .and change(AdminAuthorityAudit, :count).by(1)

        expect(AdminAuthorityAudit.last.action).to eq 'revoke'
      end
    end

    context '対象が既に一般ユーザーの場合（冪等）' do
      let!(:other_admin) { create(:administrator) }
      let(:target) { create(:user) }

      it '状態を変えず成功扱いとし、監査記録もしない' do
        result = nil
        expect { result = described_class.revoke(target_user: target, operator: operator) }
          .not_to change(AuditLog, :count)

        expect(result.success?).to be true
        expect(result.changed).to be false
      end
    end

    context '操作者自身を剥奪しようとした場合' do
      it '拒否し、権限変更も監査記録もしない' do
        result = nil
        expect { result = described_class.revoke(target_user: operator, operator: operator) }
          .not_to change(AuditLog, :count)

        expect(result.success?).to be false
        expect(result.error).to eq :self
        expect(operator.reload).to be_is_system_admin
      end
    end

    context '剥奪により管理者が0名になる場合（最後の1名）' do
      # 認可済み経路では操作者自身が唯一の管理者となり self 判定が先行するため、
      # ここでは last_one ロジックを単体で検証する目的で、操作者と異なる対象を唯一の
      # 管理者として構成する。
      let!(:target) { create(:administrator) }
      let(:operator) { create(:user) }

      it '拒否し、権限変更も監査記録もしない' do
        result = nil
        expect { result = described_class.revoke(target_user: target, operator: operator) }
          .not_to change(AuditLog, :count)

        expect(result.success?).to be false
        expect(result.error).to eq :last_one
        expect(target.reload).to be_is_system_admin
      end
    end
  end

  describe '記録失敗時の原子性' do
    let!(:target) { create(:user) }

    it '監査ログの insert が失敗すると権限変更もロールバックする' do
      allow(AuditLog).to receive(:create!).and_raise('audit insert failed')

      expect { described_class.grant(target_user: target, operator: operator) }
        .to raise_error('audit insert failed')
      expect(target.reload).not_to be_is_system_admin
    end
  end
end
