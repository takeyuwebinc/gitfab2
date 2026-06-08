# ChangeSpec: スパム認定の取消機能（要件2.4）

## 変更の目的

システム管理者が、スパム認定済みプロジェクトを管理画面の一覧から個別に取消（復帰）できるようにする。非破壊化（2.3）により認定後も内容が保持されるため、取消で `is_deleted=false` に戻せば施策以降の認定分は元通り表示される。背景・根拠は要件定義書 [spam-moderation-enhancement.md](../requirements/spam-moderation-enhancement.md) の 2.4。

UI・操作系はコメント/カード/タグのスパム管理（`Admin::Comments` 系の `resource :spam` + `?status=` フィルタ index）と同型のパターンを採用する。

## 現状

### スパム認定（2.1 / 2.3 で実装済み）

- 認定は `Admin::ProjectsController#destroy`（[admin/projects_controller.rb:12-20](../../app/controllers/admin/projects_controller.rb#L12-L20)）/ `#batch_spam`（[:22-37](../../app/controllers/admin/projects_controller.rb#L22-L37)）が `SpamDesignationService.call` を呼ぶ。
- `SpamDesignationService#designate`（[spam_designation_service.rb:35-44](../../app/services/spam_designation_service.rb#L35-L44)）は transaction 内で `register_owner_as_spammer` と `project.hide_as_spam!` を実行。
- `register_owner_as_spammer` → `target_users`（[:46-59](../../app/services/spam_designation_service.rb#L46-L59)）: owner が User なら `[owner]`、Group なら `owner.members`（**現メンバー**）に対し `User#spam_detect!`。
- `Project#hide_as_spam!`（[project.rb:171-178](../../app/models/project.rb#L171-L178)）は `is_deleted=true` と `spam_hidden_at`（認定日時）を記録する非破壊メソッド。`spam_hidden_at` の有無で通常削除と区別できる。
- `User#spam_detect!`（[user.rb:175-178](../../app/models/user.rb#L175-L178)）は `Spammer` を作成（冪等）。`User has_one :spammer`（[user.rb:50](../../app/models/user.rb#L50)）。

### 取消に未整備な点

- `Project` に取消の対メソッド（`is_deleted=false` / `spam_hidden_at=nil`）が無い。
- `User` に Spammer 解除メソッドが無い（管理画面 `Admin::SpammersController#destroy` は `Spammer.find(id).destroy!` で個別削除のみ）。
- 取消用のサービス・コントローラ・ルート・UI が無い。
- `Admin::ProjectsController#index`（[:4-8](../../app/controllers/admin/projects_controller.rb#L4-L8)）は `Project.published`（= `active` かつ非 private、[project.rb:71-75](../../app/models/project.rb#L71-L75)）のみを表示し、スパム認定済みを一覧する手段が無い。
- `Project` にスパム認定済みを絞る scope が無い。

### 一覧対象の定義（要件 2.4.2 との整合）

要件 2.4.2 は一覧対象を「`is_deleted=true` のプロジェクト」とするが、`is_deleted=true` は通常削除（`ProjectsController#destroy`、`User#resign!`、`Group#soft_destroy_all!`）でも立ち、スパム認定と区別できない。`spam_hidden_at`（2.3 で追加）の有無で区別できるため、本変更では**一覧対象を `spam_hidden_at` 有りのみ**とする。

施策前にスパム認定されたプロジェクトは `spam_hidden_at` を持たず通常削除と区別不能、かつ関連レコード物理削除済みで復元不可（要件 2.3.4）。本変更では一覧に含めない。要件 2.4.3（施策前分を一覧に含め復元不可を明示）は、施策前分を識別できないため適用しない。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/models/project.rb](../../app/models/project.rb) | `hide_as_spam!` の定義。取消の対メソッドと一覧用 scope を追加する |
| [app/models/user.rb](../../app/models/user.rb) | `spam_detect!` の定義。Spammer 解除メソッドを追加する |
| [app/services/spam_designation_service.rb](../../app/services/spam_designation_service.rb) | 認定サービス。取消サービスの設計参照元（`target_users` ロジックを踏襲） |
| [app/controllers/admin/projects_controller.rb](../../app/controllers/admin/projects_controller.rb) | `index` に status フィルタを追加。認定起点は不変 |
| [app/controllers/admin/comments/spams_controller.rb](../../app/controllers/admin/comments/spams_controller.rb) | コメント系取消の設計参照元（`resource :spam` destroy パターン） |
| [app/views/admin/projects/index.html.slim](../../app/views/admin/projects/index.html.slim) | 認定一覧ビュー。スパム認定済み一覧＋取消ボタンを追加する |
| [config/routes.rb](../../config/routes.rb) | admin namespace に取消ルートを追加する |

## 変更内容

- **追加（モデル）**: `Project#unhide_as_spam!`（bang）を新設。`is_deleted=false` と `spam_hidden_at=nil` への更新のみ。失敗時は例外を送出し、呼び出し側トランザクションでロールバック可能にする。
- **追加（モデル）**: `Project` にスパム認定済みを絞る scope（`spam_hidden_at` 有り、認定日時降順）を追加。
- **追加（モデル）**: `User` に Spammer 解除メソッドを新設。`spammer` が存在すれば破棄、無ければ何もしない（冪等）。
- **追加（サービス）**: 取消サービスを新設（認定サービスの対）。単一プロジェクトを受け、transaction 内で「owner（Group は取消時点の現メンバー）の Spammer 解除」と「`project.unhide_as_spam!`」を実行する。`target_users` の場合分け（User→owner / Group→現メンバー）は認定サービスと同一ロジックを踏襲する。成否（真偽値）を返し、コントローラが notice/alert を出し分ける（一括処理は無いため認定サービスの `Result` は用いない）。
- **追加（ルート）**: `resources :projects` 配下に取消用のネスト `resource :spam, only: :destroy`（module: projects）を追加。`DELETE /admin/projects/:project_id/spam`。
- **追加（コントローラ）**: `Admin::Projects::SpamsController#destroy` を新設。対象プロジェクトを取得し取消サービスを呼び、`?status=spam` の一覧へ notice/alert 付きでリダイレクトする。
- **変更（コントローラ）**: `Admin::ProjectsController#index` に status フィルタを追加。`status=spam` のときスパム認定済み一覧（上記 scope）、それ以外は現状どおり `Project.published`。いずれもキーワード検索（`search_draft`）を適用する。`project_comments#index` の `params[:status]` 方式に揃える。
- **変更（ビュー）**: `admin/projects/index.html.slim` の検索フォームに「スパム」チェックボックス（チェックで `status=spam` を送信）を追加し、認定対象一覧とスパム認定済み一覧を切り替える。スパム認定済み一覧時は「スパム認定取消」ボタン（`button_to` で `DELETE` ＋確認ダイアログ）を表示し、認定モード時は既存の一括認定フォームを維持、取消モードでは表示しない。
- **不変更**: 認定経路（`#destroy` / `#batch_spam` / `SpamDesignationService`）、通常削除経路、`hide_as_spam!` は変更しない。
- **関連スパムマークの独立性（2.4.5）**: 取消はプロジェクト配下のコメント/カード/タグの `SpamMarkable` status を変更しない。それらは各 `Admin::*` から個別に解除する。

> メソッド名・サービス名は実装時に確定する。`Project#hide_as_spam!` の対であることが分かる名称（例: `unhide_as_spam!`）、認定サービス `SpamDesignationService` の対であることが分かるサービス名を選ぶ。`SpamMarkable#unmark_spam!`（コメント/カード/タグ用）とは別物のため衝突・混同を避ける。

## 採用した実装パターン

| # | 判断ポイント | 採用案 |
|---|------------|--------|
| 1 | 取消一覧の対象 | `spam_hidden_at` 有りのみ（通常削除を除外）。施策前分は識別不能のため対象外 |
| 2 | 取消 UI / ルーティング | `admin_projects#index` に status フィルタを追加し、ネスト `resource :spam, only: :destroy` で取消。コメント管理と同型 |
| 3 | 取消の状態変更とSpammer解除の置き場所 | 認定サービスの対となる取消サービスに集約（transaction＋group現メンバー解決） |

却下案（#1）: 全 `is_deleted=true` を対象 — 通常削除（ユーザー削除・退会・グループ削除）の正規プロジェクトを巻き込み、誤復活・オーナーの誤 Spammer 解除を招くため不採用。
却下案（#2）: 専用コントローラ `admin/spam_projects` 新設 — 認定（projects#index）と取消で画面・責務が分散。既存のコメント管理パターン（同一 index の status 切替）と不整合になるため不採用。
却下案（#3）: コントローラに取消ロジックを直書き — group 現メンバーの Spammer 解決＋transaction はドメインロジックであり、認定サービスと対称に保つため不採用。

ADR は作成しない。本機能の戦略的判断（取消可能性・施策前データ復元不可）は要件定義書 2.4 / 2.3.4 に記録済み。戦術的判断は本 ChangeSpec とコードコメントで担保する（本機能群で確立された方針）。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | 取消コントローラ → 取消サービス → `Project#unhide_as_spam!` / `User` の Spammer 解除 | （新規） | Functional(1)/同〜近コンテキスト OK | 認定経路（`SpamDesignationService` → `hide_as_spam!` / `spam_detect!`）と対称。新たな不均衡は生じない |
| 2 | `Admin::ProjectsController#index` の status 分岐 | Model(2)/同コンテキスト | Model(2)/同コンテキスト | scope 呼び分けの追加のみ。結合悪化なし |

## 影響範囲

- **管理画面の挙動追加**: 認定済み一覧の表示と個別取消が可能になる。認定（designate）側の挙動は不変。
- **施策前分は対象外（要件 2.4.3 不適用）**: 施策前にスパム認定されたプロジェクトは `spam_hidden_at` を持たず通常削除と識別不能のため、一覧にも取消にも含めない。要件 2.4.3（施策前分を一覧へ含め復元不可を明示）は識別不能のため適用しない。
- **取消の処理（2.4.4）**: `is_deleted=false` 復帰、owner（Group は取消時点の現メンバー）の Spammer 解除、施策以降の認定分は関連レコード保持済みのため復帰で元通り表示。
- **Spammer 解除の範囲（2.5 との関係）**: 本変更の取消は当該プロジェクトの owner/現メンバーの Spammer を無条件に解除する（要件 2.4.4.2 準拠）。owner が他のスパム（別プロジェクト・別コメント等）でも Spammer 登録されている場合、本取消で解除されることになる。条件付き解除（他にスパム痕跡が無い場合のみ解除）は要件 2.5「スパマー登録の自動解除」の領域であり、本変更では扱わない。
- **新規テスト**:
  - `Project#unhide_as_spam!`（`is_deleted=false` / `spam_hidden_at=nil`）と scope（`spam_hidden_at` 有りのみ抽出）。
  - `User` の Spammer 解除メソッド（存在時破棄・非存在時冪等）。
  - 取消サービス（User 所有 / Group 所有=現メンバー解除 / `unhide_as_spam!` 実行 / 失敗時ロールバック）。
  - `Admin::Projects::SpamsController#destroy`（取消サービス呼び出し・リダイレクト）。
  - `Admin::ProjectsController#index` の status フィルタ（spam 一覧に通常削除が含まれないこと）。
- **ログ・監査**: 認定（`SpamDesignationService`）が業務監査ログを残していないのと同様、取消でも監査ログ要件は要件 2.4 に無いため追加しない。`spam_detection_logs` は検出ログであり本変更の対象外。

## 関連 ADR

- なし。戦略的判断は要件定義書 2.4 / 2.3.4 に記録済み。戦術的判断（一覧対象を `spam_hidden_at` 有りに限定・取消サービスへの集約）は本 ChangeSpec とコードコメントで担保する。

## 受け入れ条件

要件定義書 2.4 に対応:

- [ ] `spam_hidden_at` 有りのプロジェクトのみが取消一覧に表示される
- [ ] 通常削除（ユーザー削除・退会・グループ削除）のプロジェクトは取消一覧に表示されない
- [ ] 個別取消でプロジェクトの `is_deleted` が `false`、`spam_hidden_at` が `nil` に戻る
- [ ] 取消時、owner（Group の場合は取消時点の全メンバー）の Spammer 登録が、他のスパム痕跡の有無を問わず解除される
- [ ] 施策以降に認定されたプロジェクトは、取消で関連レコード・title/name が元通りに表示される
- [ ] 取消はプロジェクト配下のコメント/カード/タグの spam status を変更しない（2.4.5）

リグレッション防止（本変更で壊してはならない既存挙動）:

- [ ] スパム認定（`#destroy` / `#batch_spam` / `SpamDesignationService`）が従来どおり動作する
- [ ] 通常削除経路（`ProjectsController#destroy` / `User#resign!` / `Group#soft_destroy_all!`）が従来どおり動作する
- [ ] `Admin::ProjectsController#index` の通常（認定対象）一覧が従来どおり `Project.published` を表示する
