class Admin::Comments::ApprovalsController < Admin::Comments::BaseController
  def create
    fetch_comment.approve!
    redirect_to public_send(:"admin_#{comment_class.name.underscore.pluralize}_path", status: params[:status]), notice: "コメントを承認しました"
  end

  def destroy
    fetch_comment.unapprove!
    redirect_to public_send(:"admin_#{comment_class.name.underscore.pluralize}_path", status: params[:status]), notice: "コメントの承認を取り消ししました"
  end
end
