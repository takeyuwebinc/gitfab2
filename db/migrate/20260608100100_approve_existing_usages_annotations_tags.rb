class ApproveExistingUsagesAnnotationsTags < ActiveRecord::Migration[7.2]
  # status: 0=未確認 1=承認済み 2=スパム（SpamMarkable の enum）
  #
  # スパム運用導入前から存在する Usage / Annotation / Tag は正規コンテンツのため
  # 承認済みとして扱い、管理画面の未確認キューには新規投稿のみを残す。
  # 以降に作成されるレコードは既定の未確認（モデレーション対象）のままとする。
  # Usage / Annotation / Tag を承認済みにする経路は本マイグレーションのみのため、
  # down は承認済み（1）を未確認（0）へ戻す。
  def up
    execute "UPDATE cards SET status = 1 WHERE type IN ('Card::Usage', 'Card::Annotation') AND status = 0"
    execute "UPDATE tags SET status = 1 WHERE status = 0"
  end

  def down
    execute "UPDATE cards SET status = 0 WHERE type IN ('Card::Usage', 'Card::Annotation') AND status = 1"
    execute "UPDATE tags SET status = 0 WHERE status = 1"
  end
end
