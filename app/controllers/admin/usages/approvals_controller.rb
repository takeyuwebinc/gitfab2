class Admin::Usages::ApprovalsController < Admin::Comments::ApprovalsController
  private

  def markable_class
    Card::Usage
  end
end
