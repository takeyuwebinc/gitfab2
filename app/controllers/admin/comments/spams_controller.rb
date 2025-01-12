class Admin::Comments::SpamsController < Admin::Comments::BaseController
  def create
    fetch_comment.mark_spam!
    redirect_to public_send(:"admin_#{comment_class.name.underscore.pluralize}_path", status: params[:status]), notice: "コメントをスパムとして記録しました"
  end

  def destroy
    fetch_comment.unmark_spam!
    redirect_to public_send(:"admin_#{comment_class.name.underscore.pluralize}_path", status: params[:status]), notice: "スパムコメントを未確認に戻しました"
  end
end
