require 'spec_helper'

RSpec.describe Ability do
  subject(:ability) { described_class.new(operator) }

  describe ':grant_admin_authority（付与）' do
    context '操作者がシステム管理者の場合' do
      let(:operator) { create(:administrator) }

      it '他ユーザーへの付与を許可する' do
        target = create(:user)
        expect(ability.can?(:grant_admin_authority, target)).to be true
      end
    end

    context '操作者がシステム管理者でない場合' do
      let(:operator) { create(:user) }

      it '付与を許可しない' do
        target = create(:user)
        expect(ability.can?(:grant_admin_authority, target)).to be false
      end
    end
  end

  describe ':revoke_admin_authority（剥奪）' do
    context '操作者がシステム管理者の場合' do
      let!(:operator) { create(:administrator) }

      it '操作者自身への剥奪を拒否する' do
        # can :manage, User, id: user.id（自分自身の管理）が剥奪を含むため、
        # 自己剥奪が誤って許可されないことの回帰検証も兼ねる。
        expect(ability.can?(:revoke_admin_authority, operator)).to be false
      end

      it '唯一の管理者（最後の1名）への剥奪を拒否する' do
        # operator が唯一の管理者。自己かつ最後の1名のため拒否される。
        expect(operator.last_system_admin?).to be true
        expect(ability.can?(:revoke_admin_authority, operator)).to be false
      end

      it '複数管理者が存在する場合、他の管理者への剥奪を許可する' do
        other_admin = create(:administrator)
        expect(ability.can?(:revoke_admin_authority, other_admin)).to be true
      end
    end

    context '操作者がシステム管理者でない場合' do
      let(:operator) { create(:user) }

      it '剥奪を許可しない' do
        target = create(:administrator)
        expect(ability.can?(:revoke_admin_authority, target)).to be false
      end
    end
  end
end
