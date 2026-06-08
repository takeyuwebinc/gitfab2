# プロジェクトのスパム認定を取り消すサービス
#
# プロジェクトを再表示し、オーナー（Group の場合は取消時点の全メンバー）の
# Spammer 登録を解除する。認定サービス SpamDesignationService の対。
class SpamDesignationRevocationService
  def self.call(project)
    new.call(project)
  end

  def call(project)
    ActiveRecord::Base.transaction do
      unregister_owner_as_spammer(project)
      project.unhide_as_spam!
    end
    true
  rescue => e
    Rails.logger.error("SpamDesignationRevocationService: Failed to revoke spam designation for project #{project.id}: #{e.message}")
    false
  end

  private

  def unregister_owner_as_spammer(project)
    target_users(project).each(&:spam_undetect!)
  end

  # 解除対象。Group は取消時点の現メンバーを対象とし、認定時点のメンバー履歴は参照しない。
  def target_users(project)
    case project.owner
    when User
      [project.owner]
    when Group
      project.owner.members.to_a
    else
      []
    end
  end
end
