class Admin::Comments::BaseController < Admin::ApplicationController
  private

  # スパムマーク対象のモデルクラス。コントローラの名前空間から導出する。
  # 名前空間と実モデルが一致しないもの（例: Admin::Usages -> Card::Usage）では
  # サブクラスで override する。
  def markable_class
    resource_namespace.singularize.constantize
  end

  # ルートヘルパー・パラメータで使うリソース名。名前空間から導出する。
  # 例: Admin::Usages::SpamsController -> "usage"
  def resource_key
    resource_namespace.singularize.underscore
  end

  def resource_namespace
    self.class.name.split(/::/)[-2]
  end

  def markable_id
    params[:"#{resource_key}_id"]
  end

  def fetch_markable
    markable_class.find(markable_id)
  end

  def markable_index_path(**options)
    public_send(:"admin_#{resource_key.pluralize}_path", **options)
  end
end
