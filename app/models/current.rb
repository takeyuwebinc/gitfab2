# リクエスト単位で共有する状態を保持する。admin には操作中の管理者ユーザーを載せ、
# 監査ログ記録のコールバックが操作者を参照できるようにする。Admin 配下のリクエストで
# のみ設定され、リクエスト外（ジョブ・rake）からの呼び出しでは nil となる。
class Current < ActiveSupport::CurrentAttributes
  attribute :admin
end
