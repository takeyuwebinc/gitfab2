class Admin::Usages::SpamsController < Admin::Comments::SpamsController
  private

  def markable_class
    Card::Usage
  end
end
