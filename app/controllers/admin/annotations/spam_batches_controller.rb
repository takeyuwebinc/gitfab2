class Admin::Annotations::SpamBatchesController < Admin::Comments::SpamBatchesController
  private

  def markable_class
    Card::Annotation
  end
end
