class Admin::Projects::SpamsController < Admin::ApplicationController
  def destroy
    project = Project.friendly.find(params[:project_id])

    if SpamDesignationRevocationService.call(project)
      redirect_to admin_projects_path(status: 'spam'), notice: 'スパム認定を取り消しました'
    else
      redirect_to admin_projects_path(status: 'spam'), alert: 'スパム認定の取消に失敗しました'
    end
  end
end
