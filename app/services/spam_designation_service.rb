# プロジェクトのスパム認定処理を行うサービス
#
# オーナーをSpammerとして登録し、プロジェクトを論理削除する
class SpamDesignationService
  Result = Data.define(:success, :failed, :errors)

  def self.call(projects)
    new.call(projects)
  end

  # プロジェクトの一括スパム認定
  def call(projects)
    success_count = 0
    failed_projects = []
    errors = {}

    projects.each do |project|
      if designate(project)
        success_count += 1
      else
        failed_projects << project
        errors[project.id] = "処理に失敗しました"
      end
    end

    Result.new(
      success: success_count,
      failed: failed_projects,
      errors: errors
    )
  end

  private

  def designate(project)
    ActiveRecord::Base.transaction do
      register_owner_as_spammer(project)
      project.soft_destroy!
    end
    true
  rescue => e
    Rails.logger.error("SpamDesignationService: Failed to designate project #{project.id} as spam: #{e.message}")
    false
  end

  def register_owner_as_spammer(project)
    target_users(project).each(&:spam_detect!)
  end

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
