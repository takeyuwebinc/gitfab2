# リクエスト単位で共有する状態を保持する。admin には操作中の管理者ユーザー、
# ip_address にはリクエスト元 IP を載せ、監査ログ記録のコールバックが操作者と発生元を
# 参照できるようにする。Admin 配下のリクエストでのみ設定され、リクエスト外（ジョブ・
# rake）からの呼び出しでは nil となる。
class Current < ActiveSupport::CurrentAttributes
  attribute :admin, :ip_address
end
