# ChangeSpec: スパム認定処理の非破壊化（要件2.3）

## 変更の目的

スパム認定時の破壊的処理（title/name の匿名化・関連レコードの物理削除）を取りやめ、`is_deleted=true` による非表示化のみにする。これにより、後続の取消機能（要件2.4）で認定を元に戻せるようにする。背景・根拠は要件定義書 [spam-moderation-enhancement.md](../requirements/spam-moderation-enhancement.md) の 2.3.1 / 2.3.4。

## 現状

スパム認定は `SpamDesignationService#designate`（[spam_designation_service.rb:35-44](../../app/services/spam_designation_service.rb#L35-L44)）が、トランザクション内で `register_owner_as_spammer` と `project.soft_destroy!` を実行する。

`Project#soft_destroy!`（[project.rb:157-169](../../app/models/project.rb#L157-L169)）の実体は破壊的:

1. `title='Deleted Project'` / `name` をランダム値に更新（匿名化）
2. `is_deleted=true`
3. `likes / states / note_cards / usages / project_comments / figures / tags / collaborations` を `destroy_all`（物理削除）

`soft_destroy!`（および `Project::ProjectOwner#soft_destroy_all!`）は**スパム認定専用ではなく、正規の削除経路でも共用されている**:

| 呼び出し元 | 用途 | 破壊的処理の意図 |
|---|---|---|
| `SpamDesignationService#designate` | スパム認定 | 本変更で非破壊化する |
| `ProjectsController#destroy` / `#destroy_or_render_edit`（[:117](../../app/controllers/projects_controller.rb#L117) / [:124](../../app/controllers/projects_controller.rb#L124)） | ユーザー自身のプロジェクト削除 | 破壊を維持 |
| `User#resign!` → `projects.soft_destroy_all!`（[user.rb:148](../../app/models/user.rb#L148)） | 退会時のデータ消去 | 破壊を維持 |
| `Group#soft_destroy_all!`（[group.rb:65](../../app/models/group.rb#L65)） | グループ削除 | 破壊を維持 |

`is_deleted=true` のプロジェクトは公開画面のクエリ（`scope :active, -> { where(is_deleted: false) }` 等）で除外済みのため、関連レコードを残しても一般ユーザーには表示されない（要件 2.3.3）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/services/spam_designation_service.rb](../../app/services/spam_designation_service.rb) | スパム認定処理。`designate` で破壊メソッドを呼んでいる |
| [app/models/project.rb](../../app/models/project.rb) | `soft_destroy!`（破壊）の定義。新規に非破壊メソッドを追加する |
| [app/controllers/admin/projects_controller.rb](../../app/controllers/admin/projects_controller.rb) | スパム認定の管理画面起点。`#destroy`（[:13](../../app/controllers/admin/projects_controller.rb#L13)）/ `#batch_spam`（[:30](../../app/controllers/admin/projects_controller.rb#L30)）で `SpamDesignationService.call` を呼ぶ。公開IF不変のためコード変更は不要 |
| [spec/services/spam_designation_service_spec.rb](../../spec/services/spam_designation_service_spec.rb) | サービスの既存テスト。`soft_destroy!` をスタブする箇所あり |
| [spec/models/project_spec.rb](../../spec/models/project_spec.rb) | `soft_destroy!` の既存テスト。新規メソッドのテストを追加する |
| [spec/controllers/admin/projects_controller_spec.rb](../../spec/controllers/admin/projects_controller_spec.rb) | 管理画面のスパム認定テスト。起点の挙動確認 |

## 変更内容

- **追加**: `Project` に**スパム認定専用の非破壊メソッド**（bang）を新設する。挙動は `is_deleted=true` の更新のみ。title/name の匿名化・関連レコードの物理削除は**行わない**。失敗時は例外を送出し、呼び出し側トランザクションでロールバック可能にする。
- **変更**: `SpamDesignationService#designate` の `project.soft_destroy!` 呼び出しを、上記の新規非破壊メソッドの呼び出しに置き換える。`register_owner_as_spammer` は変更しない。
- **不変更**: `Project#soft_destroy!` 本体および正規削除3経路（`ProjectsController#destroy` / `#destroy_or_render_edit`、`User#resign!`、`Group#soft_destroy_all!`）は従来どおり破壊的挙動を維持する。

> メソッド名は実装時に確定する。意図が名前に表れる名称（例: スパム認定による非表示化であることが分かる名前）を選ぶ。`SpamMarkable#mark_spam!`（コメント/カード/タグのスパムマーク用）とは別物のため、名称の衝突・混同を避ける。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 共用 `soft_destroy!` からのスパム経路の分離方法 | スパム専用の非破壊メソッドを新設し、サービスがそれを呼ぶ（既存 `soft_destroy!` は無変更） | なし（後述） |

却下案: (a) 既存 `soft_destroy`（非bang）の流用 — `update`（非bang）で失敗時に例外を出さず、サービスの transaction ロールバックが効かないため不採用。(b) `soft_destroy!` への引数追加 — メソッドが多目的化し、全呼び出し元が引数の意味を理解する必要が生じ凝集が下がるため不採用。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `SpamDesignationService` → `Project#soft_destroy!`（4文脈で共用される汎用破壊メソッド） | Integration(4)/異コンテキスト(3) NG | Functional(1)/異コンテキスト(3) OK | スパム専用の非破壊コントラクトへ依存先を変更。共有破壊挙動への結合が解け、正規削除経路の変更がスパム認定に波及しなくなる（不均衡は減る） |

## 影響範囲

- **スパム認定の挙動変更**: 認定後もプロジェクトの title/name と関連レコードが保持される（一般ユーザー画面では `is_deleted=true` により非表示のまま）。後続の管理画面（要件2.4）が認定済みプロジェクトの内容を参照できる前提が整う。
- **正規削除経路への影響なし**: `soft_destroy!` を変更しないため、ユーザーによる削除・退会・グループ削除の挙動は不変。
- **管理画面の起点はコード変更不要**: `Admin::ProjectsController#destroy` / `#batch_spam` は `SpamDesignationService.call`（引数・戻り値 `Result` 不変）を呼ぶだけのため修正不要。ただし観測される結果（認定後にプロジェクト内容が保持される）は変わる。既存の管理画面テスト [spec/controllers/admin/projects_controller_spec.rb](../../spec/controllers/admin/projects_controller_spec.rb) が破壊的挙動に依存していないか確認する。
- **既存テストの修正**:
  - [spec/services/spam_designation_service_spec.rb](../../spec/services/spam_designation_service_spec.rb): 「プロジェクトを論理削除する」検証は `is_deleted` の変化で引き続き成立。失敗系テスト（[:83](../../spec/services/spam_designation_service_spec.rb#L83) の `allow(project2).to receive(:soft_destroy!).and_raise(...)`）は、サービスが呼ぶメソッドが変わるため**新メソッドをスタブするよう修正が必要**。
  - 「関連レコードが削除されない」「title/name が変更されない」を検証する**新規テストを追加**する。
- **新規テストの追加**: [spec/models/project_spec.rb](../../spec/models/project_spec.rb) に新規非破壊メソッドのテスト（`is_deleted=true` のみ変更し、関連レコード・title/name を保持）を追加する。

## 関連 ADR

- なし。戦略的判断（非破壊化と引き換えの取消可能性、施策前データの復元不可）は要件定義書 2.3.1 / 2.3.4 に記録済み。本変更の戦術的判断（メソッド分離）は本 ChangeSpec とコードコメントで担保し、ADR は作成しない。

## 受け入れ条件

要件定義書 5.3 に対応:

- [ ] スパム認定時、プロジェクトの title / name が変更されない
- [ ] スパム認定時、likes / states / note_cards / usages / project_comments / figures / tags / collaborations が削除されない
- [ ] スパム認定時、オーナー（Group の場合は全メンバー）が Spammer として登録される
- [ ] スパム認定後も一般ユーザー画面に該当プロジェクトが表示されない（`is_deleted=true` による除外）
- [ ] 一括認定で一部が失敗しても、失敗分と成功分が正しく報告され、成功分は `is_deleted=true` になる

リグレッション防止（本変更で壊してはならない既存挙動）:

- [ ] `ProjectsController#destroy` / `#destroy_or_render_edit` による削除は従来どおり破壊的（匿名化・関連レコード削除）に動作する
- [ ] `User#resign!` による退会時のプロジェクト消去が従来どおり動作する
- [ ] `Group#soft_destroy_all!` によるグループ削除が従来どおり動作する
