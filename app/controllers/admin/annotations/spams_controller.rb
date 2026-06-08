class Admin::Annotations::SpamsController < Admin::Comments::SpamsController
  private

  def markable_class
    Card::Annotation
  end
end
