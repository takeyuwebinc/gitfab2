class Admin::Annotations::ApprovalsController < Admin::Comments::ApprovalsController
  private

  def markable_class
    Card::Annotation
  end
end
