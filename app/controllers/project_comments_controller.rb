class ProjectCommentsController < ApplicationController
  include SpamKeywordDetection

  def create
    project = Project.find(params[:project_id])
    project_comment = ProjectComment.build_from(project, current_user, project_comment_params)

    if detect_spam_keyword(contents: project_comment.body, content_type: "ProjectComment")
      redirect_to project_path(project.owner, project, anchor: "project-comment-form"),
                  alert: spam_keyword_rejection_message,
                  flash: { project_comment_body: project_comment.body }
      return
    end

    if project_comment.save
      notify_users(project_comment)
      redirect_to project_path(project.owner, project, anchor: "project-comment-#{project_comment.id}")
    else
      redirect_to project_path(project.owner, project, anchor: "project-comment-form"),
                  alert: project_comment.errors.full_messages,
                  flash: { project_comment_body: project_comment.body }
    end
  end

  def destroy
    project_comment = ProjectComment.find(params[:id])
    project = project_comment.project

    unless project_comment.manageable_by?(current_user)
      redirect_to project_path(project.owner, project, anchor: "project-comments"),
                  alert: 'You can not delete a comment'
      return
    end

    if project_comment.destroy
      redirect_to project_path(project.owner, project, anchor: "project-comments")
    else
      redirect_to project_path(project.owner, project, anchor: "project-comments"),
                  alert: 'Comment could not be deleted'
    end
  end

  private

    def project_comment_params
      params.require(:project_comment).permit(:body)
    end

    def notify_users(project_comment)
      return if project_comment.spam?
      project = project_comment.project
      users = project.notifiable_users(current_user)
      return if users.blank?

      body = "#{current_user.name} commented on #{project.title}."
      project.notify(users, project_comment.user, project_path(project.owner, project), body)
    end
end
