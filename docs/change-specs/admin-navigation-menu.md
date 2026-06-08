# ChangeSpec: 管理画面への共通ナビゲーション（上部バー）追加

## 変更の目的

`/admin` 配下の各管理画面には、ほかの管理画面や管理ダッシュボードへ戻る導線がない。管理メニューはダッシュボード（`dashboard#index`）にしか存在せず、個別画面に遷移するとブラウザの戻る操作以外で移動できない。全管理画面に共通ナビゲーションを表示して回遊性を確保する。

## 現状

- 管理レイアウト [admin.html.slim](../../app/views/layouts/admin.html.slim) は `#content` に `yield` するだけで、`_base_layout` 経由でサイト共通ヘッダー [_header.html.slim](../../app/views/layouts/_header.html.slim) を描画する。このヘッダーはロゴ・検索・ユーザーツール用で、**管理ナビゲーションを含まない**。
- 管理メニュー（全セクションへのリンク集）は [admin/dashboard/index.html.slim](../../app/views/admin/dashboard/index.html.slim) の `nav.nav.flex-column`（14リンク）が唯一で、**このページ専用**。個別画面（features / projects / announcements / spammers / tags / usages 等）はいずれも自前の `h2` から始まり、**全管理画面を横断する共通メニューを持たない**（tags / usages / annotations / project_comments / card_comments / spammers の一部はページ内フィルタ用の `nav.flex-row` を持つが、これはセクション内の絞り込みで横断メニューではない）。
- 例外として [system_settings/edit.html.slim:58](../../app/views/admin/system_settings/edit.html.slim#L58) のみ「ダッシュボードに戻る」リンク（`admin_root_path`）を手書きしている。
- `admin_root_path` は `dashboard#index` を指す（[routes.rb:13](../../config/routes.rb#L13)）。`namespace :admin` 配下のトップレベルセクションは約14。
- スタイル資産 [admin.scss](../../app/assets/stylesheets/admin.scss) は Bootstrap の `type` / `tables` / `forms` / `buttons` / `nav` / `alert` / `utilities` を import している（`.nav`・`.nav-link` は `nav`、`.flex-row` は `utilities` の flex ユーティリティ由来）。`navbar`・`dropdown` はコメントアウト（未読込）。Bootstrap は gem 版 4.3.1。
- JS資産 [admin.js](../../app/assets/javascripts/admin.js) は `rails-ujs` のみ。Bootstrap JS / jQuery は読み込まれていない。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/views/layouts/admin.html.slim](../../app/views/layouts/admin.html.slim) | 管理画面共通レイアウト。ここに上部バーを追加する |
| [app/views/admin/dashboard/index.html.slim](../../app/views/admin/dashboard/index.html.slim) | 現状唯一のメニュー定義。リンク集を共有partial化して再利用する |
| [app/views/admin/system_settings/edit.html.slim](../../app/views/admin/system_settings/edit.html.slim) | 手書きの「ダッシュボードに戻る」リンクを持つ。上部バーと重複するため削除 |
| [app/assets/stylesheets/admin.scss](../../app/assets/stylesheets/admin.scss) | 上部バーのスタイルを追加する |
| [config/routes.rb](../../config/routes.rb) | `admin` namespace。リンク先パスの参照元（変更なし） |

## 変更内容

- **追加**: 管理メニューのリンク集を共有partial `app/views/admin/shared/_menu_links.html.slim` に切り出す。中身は現状ダッシュボードにある14セクションへの `link_to`（`nav-link` クラス付き）のみとし、ラッパー（`nav` 要素）は呼び出し側が用意する。これによりリンク定義を単一の情報源にする。リンク集合は**現状のダッシュボードと同一の14セクション**とし、新規セクションは追加しない（`featured_items` は `features` 配下のネストリソースで単独の一覧ページを持たない（partial と jbuilder のみ）ため、横断メニューには含めない）。
- **追加**: 管理レイアウト [admin.html.slim](../../app/views/layouts/admin.html.slim) に上部ナビゲーションバー（横並び）を追加する。`#content` の上に `nav#admin-nav.nav.flex-row` を配置し、先頭に「管理ダッシュボード」への戻りリンク（`admin_root_path`）を置いた上で `_menu_links` を描画する。これにより**全管理画面**に共通の導線が表示される。
- **追加**: [admin.scss](../../app/assets/stylesheets/admin.scss) に上部バー（`#admin-nav`）の最小スタイルを追加する。横幅超過時の折り返し（14リンクが画面幅を超えても折り返して全リンクが見える）、リンク間余白、コンテンツ領域との境界（下罫線・背景）を整える。`.nav` / `.nav-link` は既存の `nav` import、`.flex-row` は既存の `utilities` import で利用可能なため、`navbar`・`dropdown` の追加読込やJS追加は行わない。
- **変更**: [dashboard/index.html.slim](../../app/views/admin/dashboard/index.html.slim) のインラインのリンク列を `_menu_links` partial の描画に置き換える。「Administration Menu」見出しと `nav.nav.flex-column`（縦一覧）の表示形式は現状維持する。
- **削除**: [system_settings/edit.html.slim:58](../../app/views/admin/system_settings/edit.html.slim#L58) の「ダッシュボードに戻る」リンク。上部バーが全画面で同等の導線を提供するため重複となる。「保存」ボタンの行はそのまま残す。

## 影響範囲

- **全管理画面の表示**: フルページHTML描画される全 `/admin` 画面の上部に共通バーが追加される。対象は各セクションの index に加え、admin レイアウトを使う show / new / edit ビュー（announcements の new/edit/show、black_lists の new/show、projects の show、spam_keywords の new/edit、features の update）も含む。各画面の見出し（`h2`）位置が下にずれる。
- **レイアウトを描画しない応答（影響なし）**: features フォームの `remote: true`（JSON jbuilder 応答）、および各 spam / approval / spam_batch 系のネストコントローラ（`Admin::Projects::SpamsController` 等、`redirect_to` または JSON で応答）はレイアウトHTMLを全描画しないため、上部バーは描画されず影響なし。
- **ダッシュボード画面**: 上部バーと従来の縦メニュー一覧が併存する（ユーザー選択により縦一覧を維持）。リンク定義はpartialに一本化される。
- **CSS**: `#admin-nav` のスタイル追加。既存セレクタ（`#content`、各画面固有スタイル）には影響しない想定。`navbar`/`dropdown` の import は変更しない。
- **テスト**: 本プロジェクトには現状 system / integration spec が存在せず、admin 関連テストは controller spec 主体。共通バーのリンク存在・遷移は、`render_views` を有効化したリクエスト/コントローラスペックでレイアウト込みのHTMLを描画し、`_menu_links` の14リンクと「管理ダッシュボード」リンクの存在を1か所で検証する。`system_settings` の「ダッシュボードに戻る」リンク削除を検証している既存テストは存在しない（grep 済み）ため修正不要だが、削除後も上部バー経由で戻れることを上記スペックでカバーする。

## 関連 ADR

- なし（構造は「共有partialをレイアウトで描画」という Rails 慣用パターンの踏襲で代替検討不要。表示形式はUI選好として上部バーをユーザーと合意済みで、アーキテクチャ判断を伴わないため ADR 起票不要）

## 受け入れ条件

- [ ] `/admin` 配下の各画面（dashboard 以外。例: features, projects, announcements, spammers, tags, usages, system_settings）で、上部バーに全14セクションへのリンクと「管理ダッシュボード」への戻りリンクが表示される
- [ ] 上部バーの各リンクから対応する管理画面へ遷移できる
- [ ] 上部バーの「管理ダッシュボード」リンクから `admin_root_path`（dashboard#index）へ戻れる
- [ ] ダッシュボード（index）の「Administration Menu」縦一覧が従来どおり表示される
- [ ] 管理メニューのリンク定義が `_menu_links` partial の1か所に集約され、ダッシュボードと上部バーの双方がそれを参照している
- [ ] system_settings 編集画面から手書きの「ダッシュボードに戻る」リンクが削除され、上部バー経由で戻れる
- [ ] index 以外の admin レイアウトを使う画面（例: projects/show、announcements/new・edit、spam_keywords/new・edit）でも上部バーが表示され、既存コンテンツの表示が崩れない（14リンクが画面幅を超える場合は折り返して全リンクが見える）
- [ ] `remote: true` の Ajax 応答およびネストコントローラの redirect/JSON 応答には上部バーが含まれない（レイアウト非描画が維持される）
- [ ] 非管理者ユーザーが `/admin` 配下にアクセスした場合は従来どおり `root_path` にリダイレクトされる（既存の認可挙動が維持される）
