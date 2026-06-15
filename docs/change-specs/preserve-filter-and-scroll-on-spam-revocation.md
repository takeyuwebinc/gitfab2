# ChangeSpec: スパム認定取消時にフィルタ・ページ・スクロール位置を維持する

## 変更の目的

「Edit Projects」のスパム一覧で「スパム認定取消」を実行すると、検索キーワード・ページ番号が失われ1ページ目に戻り、スクロール位置もリセットされる。「Review Project Comments」の「承認」「未承認に戻す」と同じ操作感（操作後も同じ位置・条件のまま）に揃える。

## 現状

- スパム一覧の「スパム認定取消」ボタンは [app/views/admin/projects/index.html.slim:33](../../app/views/admin/projects/index.html.slim#L33) で `button_to` により描画され、`data: { confirm: 'スパム認定を取り消しますか？' }`（Rails UJS の確認ダイアログ）のみを指定している。`form: { data: { turbo: true } }` を指定していないため Turbo morph に opt-in しておらず、操作後にスクロール位置がリセットされる。
- ボタンのURL（`admin_project_spam_path(project)`）に検索キーワード `q`・ページ番号 `page` を渡していない。
- [app/controllers/admin/projects/spams_controller.rb:6-8](../../app/controllers/admin/projects/spams_controller.rb#L6-L8) のリダイレクト先は `admin_projects_path(status: 'spam')` 固定で、`q`・`page` を引き継がない。このため取消後は常に検索条件なし・1ページ目に戻る。
- レイアウト [app/views/layouts/admin.html.slim:2-3](../../app/views/layouts/admin.html.slim#L2-L3) に `turbo-refresh-method=morph` / `turbo-refresh-scroll=preserve` が既に設定済み。ボタン側で Turbo に opt-in するだけでスクロール維持が機能する。
- 同等パターンは既に [app/views/admin/project_comments/index.html.slim:53-57](../../app/views/admin/project_comments/index.html.slim#L53-L57)（承認/未承認に戻す）と直近コミット d3e6fe30（スパム投稿者取り消し）で実装済み。本変更はそれらの踏襲。
- 確認文言を伴う Turbo ボタンの先行例は [app/views/admin/project_comments/index.html.slim:23](../../app/views/admin/project_comments/index.html.slim#L23)（`turbo_confirm`）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/views/admin/projects/index.html.slim](../../app/views/admin/projects/index.html.slim) | スパム一覧と「スパム認定取消」ボタンのビュー |
| [app/controllers/admin/projects/spams_controller.rb](../../app/controllers/admin/projects/spams_controller.rb) | 取消処理と取消後のリダイレクト |
| [spec/controllers/admin/projects/spams_controller_spec.rb](../../spec/controllers/admin/projects/spams_controller_spec.rb) | コントローラのテスト |

## 変更内容

- **変更（ビュー）**: 「スパム認定取消」ボタンを Turbo morph に opt-in し、確認ダイアログを Turbo 方式へ移行する。
  - `form: { data: { turbo: true, turbo_confirm: 'スパム認定を取り消しますか？' } }` を指定する。
  - 既存の `data: { confirm: ... }` は削除する（Turbo opt-in 下では UJS の confirm が発火しないため `turbo_confirm` へ置き換え）。
  - ボタンURLに現在の検索キーワード `q` とページ番号 `page` を付与する（`admin_project_spam_path(project, q: params[:q], page: params[:page])`）。
- **変更（コントローラ）**: 成功時・失敗時いずれのリダイレクト先にも `q`・`page` を引き継ぐ（`admin_projects_path(status: 'spam', q: params[:q], page: params[:page])`）。`status: 'spam'` は従来どおり固定。

## 影響範囲

- 影響対象は管理画面「Edit Projects」のスパム一覧のみ。スパム認定取消の業務ロジック（`SpamDesignationRevocationService`）には変更なし。
- スパム以外の一覧（`@status != 'spam'` 側のまとめてスパム認定フォーム）には影響しない。
- テスト: [spec/controllers/admin/projects/spams_controller_spec.rb](../../spec/controllers/admin/projects/spams_controller_spec.rb) の既存ケースは `q`・`page` を渡さない DELETE を送るため、期待値 `admin_projects_path(status: 'spam')` は変更後も一致する（修正不要）。これとは別に、`q`・`page` を指定した DELETE が両パラメータを引き継いでリダイレクトすることを保証する新規ケースを追加する（d3e6fe30 のスパム投稿者テストと同形式）。

## 関連 ADR

- なし（既存パターンの踏襲のため）

## 受け入れ条件

- [ ] 検索キーワード・ページ番号を指定したスパム一覧で「スパム認定取消」を実行すると、取消後も同じ検索キーワード・同じページが維持される（成功時・失敗時とも）。
- [ ] 取消操作後にページ全体が再描画されず、スクロール位置が維持される（Turbo morph による）。
- [ ] 「スパム認定取消」クリック時に確認ダイアログ「スパム認定を取り消しますか？」が表示され、キャンセルすると取消が実行されない。
- [ ] コントローラ仕様で、`q: 'keyword'`・`page: '2'` を指定した DELETE が `admin_projects_path(status: 'spam', q: 'keyword', page: '2')` へリダイレクトすることを検証する（成功時・失敗時とも）。既存の `q`・`page` なしケースのリダイレクト期待値は変更後も一致する。
