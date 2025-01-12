class Admin::Comments::BaseController < Admin::ApplicationController
  private

  def comment_class
    self.class.name.split(/::/)[-2].singularize.constantize
  end

  def comment_id
    params[:"#{comment_class.name.underscore}_id"]
  end

  def fetch_comment
    comment_class.find(comment_id)
  end
end
