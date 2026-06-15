# ChangeSpec: 管理画面「まとめてスパム認定」でフィルタ・ページを維持

## 変更の目的

管理画面「Edit Projects」で「まとめてスパム認定」を実行すると、リダイレクト先が `admin_projects_path`（パラメータなし）固定のため、検索フィルタ（`q`）とページ（`page`）が失われ、1ページ目・フィルタ解除状態に戻ってしまう。連続して複数ページ・絞り込み状態を確認しながら作業する運用を妨げるため、認定後も直前の表示状態を維持する。操作後にページ・絞り込みを維持する方針自体は、別画面のスパム投稿者管理（`Admin::SpammersController`、コミット d3e6fe30）で先行採用済みであり、それと整合させる。

## 現状

- `Admin::ProjectsController#index` は `params[:status]` / `params[:q]` / `params[:page]`（kaminari）で一覧を絞り込む。`status == 'spam'` のときはスパム認定済み一覧（取消画面）、それ以外は公開プロジェクト一覧（まとめてスパム認定画面）を表示する。
- 「まとめてスパム認定」は `status != 'spam'`（公開一覧）側に表示される POST フォーム `batch-spam-form`。送信内容はチェックボックス `project_ids[]` のみで、`q` / `page` を送出していない。
- `#batch_spam` は成功・失敗・未選択のいずれも `redirect_to admin_projects_path`（パラメータなし）でリダイレクトする。
- このフォームは `status != 'spam'` のときのみ描画されるため、`status` はこの経路では常に非 'spam'（実質ブランク）であり、`index` のクエリ分岐にも影響しない。維持対象として意味を持つのは `q`（検索フィルタ）と `page`（ページ）のみ。
- 同一画面のスパム取消側 `Admin::Projects::SpamsController#destroy` は `admin_projects_path(status: 'spam')` にリダイレクトし、`status` のみ維持して `page` / `q` は維持していない（本変更のスコープ外）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/controllers/admin/projects_controller.rb](../../app/controllers/admin/projects_controller.rb) | `#index` で絞り込み、`#batch_spam` で一括スパム認定後にリダイレクト |
| [app/views/admin/projects/index.html.slim](../../app/views/admin/projects/index.html.slim) | 「まとめてスパム認定」フォーム（`batch-spam-form`）と検索フォーム |
| [spec/controllers/admin/projects_controller_spec.rb](../../spec/controllers/admin/projects_controller_spec.rb) | `POST #batch_spam` のリダイレクト検証 |

## 変更内容

- **変更**: `batch-spam-form` に `q` / `page` を引き継ぐ hidden field を追加する（`hidden_field_tag`）。値は `index` 表示時の現在パラメータ（`params[:q]` / `params[:page]`）。`status` はこの経路で意味を持たないため追加しない。
- **変更**: `#batch_spam` のリダイレクト3箇所（成功・失敗・未選択）に、空でない `q` / `page` を引き継いだリダイレクト先を渡す。フィルタ・ページ未指定時に空文字が URL に残らないよう、ブランク値を除外したうえで `admin_projects_path` に渡す。

補足: `hidden_field_tag` は値が `nil`/空でも空 value の input を出力し、フォームは空文字を送信する。`admin_projects_path` は `nil` は除外するが空文字は除外しないため、リダイレクト生成時にブランク値を取り除く（例: `compact_blank` 相当の処理）。これにより、フィルタ・ページ未指定時のリダイレクト先は従来どおり `admin_projects_path`（クエリなし）と等価になる。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | POST アクションへのフィルタ・ページ引き継ぎ方法 | フォーム本文に hidden field を追加（案A） | なし（既存パターン内の軽微な選択。ADR 不要） |

却下案: フォーム action URL にクエリ付与（案B）。フォーム送信値として明示でき、空文字の扱いをコントローラ側で一元的に制御できる案Aを採用。

## 影響範囲

- `#batch_spam` のリダイレクト先のみ変更。スパム認定処理本体（`SpamDesignationService`）には変更なし。
- `batch-spam-form` の送出パラメータが増える（`project_ids[]` に加え `q` / `page`）。フォーム送信時の選択判定 JavaScript（`project_ids[]` のチェック数で判定）は新規 hidden field の影響を受けない。
- 既存テスト [projects_controller_spec.rb:101-190](../../spec/controllers/admin/projects_controller_spec.rb#L101-L190) は `q`/`page` を渡していないため、ブランク値が除外され `redirect_to(admin_projects_path)` の検証はそのまま通過する（修正不要）。
- パラメータ維持を検証する新規テストの追加が必要（後述の受け入れ条件）。
- 単一スパム認定 `#destroy`、およびスパム取消 `Admin::Projects::SpamsController#destroy`（`page`/`q` 未維持）は本変更のスコープ外。同種の不整合だが今回は対象としない。

## 関連 ADR

- なし

## 受け入れ条件

- [ ] `q` / `page` を含めて「まとめてスパム認定」を実行すると、成功時リダイレクト先がそれらのパラメータを保持している
- [ ] 一部失敗時のリダイレクト先も `q` / `page` を保持している
- [ ] 未選択で送信した場合（alert 表示時）のリダイレクト先も `q` / `page` を保持している
- [ ] フィルタ・ページ未指定（空文字含む）で送信した場合は `admin_projects_path`（クエリなし）にリダイレクトし、`?q=&page=` のような空クエリが付かない
- [ ] ビューの `batch-spam-form` に `q` / `page` の hidden field が出力され、現在の絞り込み・ページ値が設定されている
