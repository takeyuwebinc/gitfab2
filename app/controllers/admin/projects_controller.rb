class Admin::ProjectsController < Admin::ApplicationController
  before_action :load_project, only: [:show, :destroy]

  def index
    @projects = Project.published.order(created_at: :desc)
    @projects = @projects.search_draft(params[:q]) if params[:q]
    @projects = @projects.page(params[:page])
  end

  def show; end

  def destroy
    result = SpamDesignationService.call([@project])

    if result.failed.empty?
      redirect_to admin_projects_path, notice: 'プロジェクトをスパム認定しました'
    else
      redirect_to admin_projects_path, alert: 'スパム認定に失敗しました'
    end
  end

  def batch_spam
    project_ids = params[:project_ids] || []
    if project_ids.empty?
      redirect_to admin_projects_path, alert: 'プロジェクトを選択してください'
      return
    end

    projects = Project.where(id: project_ids)
    result = SpamDesignationService.call(projects)

    if result.failed.empty?
      redirect_to admin_projects_path, notice: "#{result.success}件のプロジェクトをスパム認定しました"
    else
      redirect_to admin_projects_path, alert: "#{result.success}件を処理しましたが、#{result.failed.size}件は失敗しました"
    end
  end

  private

    def load_project
      @project = Project.friendly.find(params[:id])
    end
end
