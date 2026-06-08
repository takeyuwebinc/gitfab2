class Admin::Usages::SpamBatchesController < Admin::Comments::SpamBatchesController
  private

  def markable_class
    Card::Usage
  end
end
