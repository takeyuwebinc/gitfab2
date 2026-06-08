# ChangeSpec: スパマー登録の自動解除（要件2.5）

## 変更の目的

個別レコード（コメント/カード/タグ）のスパムマーク解除時に、投稿者の Spammer 登録が残ったままになる。あらゆるスパム解除経路で投稿者の Spammer 登録を自動解除し、管理者が解除操作を1回行うだけでスパマー登録も外れるようにする。背景・根拠は要件定義書 [spam-moderation-enhancement.md](../requirements/spam-moderation-enhancement.md) の 2.5。

## 現状

### スパムマーク／解除（SpamMarkable concern）

- `SpamMarkable` を include するモデルは5種: `ProjectComment` / `CardComment` / `Tag` / `Card::Usage` / `Card::Annotation`。
- `SpamMarkable#mark_spam!`（[spam_markable.rb:28-36](../../app/models/concerns/spam_markable.rb#L28-L36)）は `with_lock` 内で、`spam_author` があれば `author.notifications_given.destroy_all` ＋ `author.spam_detect!`（Spammer 登録）を行い、status を `spam` にする。
- `SpamMarkable#unmark_spam!`（[spam_markable.rb:39-43](../../app/models/concerns/spam_markable.rb#L39-L43)）は **status を `unconfirmed` に戻すのみで、Spammer 解除を行っていない**（= 本変更のギャップ）。`unconfirmed` なら no-op（冪等）、`approved` なら例外。
- `spam_author`（[spam_markable.rb:23-25](../../app/models/concerns/spam_markable.rb#L23-L25)）は既定で `user`。`Card::Usage`（[usage.rb:34-36](../../app/models/card/usage.rb#L34-L36)）と `Card::Annotation`（[annotation.rb:37-39](../../app/models/card/annotation.rb#L37-L39)）は最古 contribution の contributor を返し、特定できない場合は `nil`。`Tag` は既定の `user`。`spam_author` は呼び出し時点で**動的算出**される（値を保存しない）点に注意（→ 変更内容の注記）。

### 解除経路（コントローラ）

- SpamMarkable を include する5種の個別解除は [Admin::Comments::SpamsController#destroy](../../app/controllers/admin/comments/spams_controller.rb#L7-L10) → `fetch_markable.unmark_spam!` の**単一経路**に集約されている（各 `Admin::*::SpamsController` は同コントローラを継承）。`unmark_spam!` の呼び出し元は他に無い。なお Project は SpamMarkable を include せず、取消は独立経路（`Admin::Projects::SpamsController` → `SpamDesignationRevocationService`、後述）で `unmark_spam!` を経由しない。
- 一括処理（`Admin::*::SpamBatchesController`）は `mark_spam!` のみで、一括解除は存在しない。

### Spammer 登録／解除（User）

- `User#spam_detect!`（[user.rb:175-178](../../app/models/user.rb#L175-L178)）は Spammer を作成（冪等）。
- `User#spam_undetect!`（[user.rb:181-183](../../app/models/user.rb#L181-L183)）は `spammer&.destroy!`。登録が無ければ何もしない（冪等）。**2.4 で新設済み**。

### プロジェクト取消経路（2.4 で実装済み）

- [SpamDesignationRevocationService](../../app/services/spam_designation_revocation_service.rb#L23-L24) が取消時に `target_users(project).each(&:spam_undetect!)`（User 所有=オーナー / Group 所有=取消時点の現メンバー）を実行済み。**要件 2.5.2 のプロジェクト行は本変更の対象外（受け入れ確認のみ）**。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/models/concerns/spam_markable.rb](../../app/models/concerns/spam_markable.rb) | `unmark_spam!` に Spammer 自動解除を追加する（本変更の唯一の実装変更） |
| [app/models/user.rb](../../app/models/user.rb) | `spam_undetect!`（2.4 新設・冪等）を利用。変更なし |
| [app/models/card/usage.rb](../../app/models/card/usage.rb) / [card/annotation.rb](../../app/models/card/annotation.rb) | `spam_author` が nil を返しうる対象。`unmark_spam!` 側で nil ガードが必要 |
| [app/controllers/admin/comments/spams_controller.rb](../../app/controllers/admin/comments/spams_controller.rb) | 全解除経路の集約点。変更なし（`unmark_spam!` 呼び出しのまま） |

## 変更内容

- **変更（モデル）**: `SpamMarkable#unmark_spam!` を、`mark_spam!` と対称な操作にする。
  - `with_lock` 内で、`spam_author` があれば `author.spam_undetect!`（Spammer 解除）を呼んでから status を `unconfirmed` に戻す。
  - 既存の状態制約を維持する: `unconfirmed` は no-op（冪等）、`approved` からの解除は例外で拒否。
  - `spam_author` が nil の場合（contribution 無しの Usage/Annotation 等）は Spammer 解除をスキップし、status 変更のみ行う（`mark_spam!` の nil ガードと対称）。
- **不変更**: `mark_spam!`、`User#spam_undetect!`（2.4 済み）、各コントローラ、ルーティング、ビュー、プロジェクト取消経路（2.4 済み）。
- **非対象（要件外）**: `mark_spam!` で削除した未読通知（`notifications_given`）の復元は行わない（不可逆・要件に無し）。

> 解除は「対象がひとつでもスパム解除されたら無条件に Spammer 登録を解除する」（要件 2.5.3）。`spam_undetect!` は他のスパム痕跡の有無を問わず破棄するため、この単純条件を満たす。`mark_spam!`↔`unmark_spam!` / `spam_detect!`↔`spam_undetect!` の**コード構造上の対称性**をコードコメントで明示する。
>
> 対称性の限界（動的 `spam_author`）: `spam_author` は呼び出し時点で動的算出されるため、Usage/Annotation でマーク後に最古 contribution が増減すると、解除時に解決される作成者がマーク時と異なりうる。本変更はマーク時の作成者を保存（スナップショット）せず、`mark_spam!` と同じ動的解決を踏襲する（要件 2.5.2 が作成者を「最古 contribution の contributor」と動的定義しており、スパム非表示中のカードで contribution が変動する実運用は想定しにくいため）。厳密なユーザー固定が必要になった場合はマーク時の作成者保存を別途検討する。

## 採用した実装パターン

| # | 判断ポイント | 採用案 |
|---|------------|--------|
| 1 | 自動解除フックの置き場所 | `SpamMarkable#unmark_spam!` に集約（`spam_author.spam_undetect!`）。`mark_spam!` と完全対称 |

却下案（#1-A）: コントローラ `Admin::Comments::SpamsController#destroy` で解除 — mark は model・unmark は controller となり対称性が崩れ、将来の別経路（一括解除等）で漏れる。不採用。
却下案（#1-B）: status 変更の `after_update` コールバック — 暗黙的で全 status 遷移（approve/unapprove・一括 mark 等）に乗り干渉、テストも困難。不採用。

ADR は作成しない。本機能の戦略的判断（あらゆる解除経路で Spammer を自動解除・誤解除リスクと引き換えの単純条件）は要件定義書 2.5 に記録済み。戦術的判断（concern への集約・対称性）は本 ChangeSpec とコードコメントで担保する（2.1〜2.4 で確立された方針と同一）。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `SpamMarkable#unmark_spam!` → `User#spam_undetect!`（`spam_author` 経由） | （新規） | Functional(1)/同〜近コンテキスト OK | 既存 `mark_spam!` → `spam_detect!` と**同一結合点の対称な逆辺**。新たな結合種別・距離・依存先の導入なし。不均衡増加なし |

## 影響範囲

- **管理画面の挙動追加**: 5種すべてのスパムマーク解除（`Admin::*::SpamsController#destroy`）で、投稿者の Spammer 登録が自動解除されるようになる。マーク（`mark_spam!`）側の挙動は不変。
- **解除の波及（要件 2.5.3 の運用上の注意）**: ユーザーが複数のスパム投稿で登録されていても、どれか1件の解除で Spammer 登録が外れる。誤って1件を解除すると他のスパム痕跡があっても登録が外れるため、運用上の注意点として要件 2.5.3 に明記済み。
- **再登録**: 解除後に再度スパムマークされれば `mark_spam!` → `spam_detect!` で再登録される（既存挙動、要件 2.1.3 末尾）。
- **過去データ（要件 2.5.5）**: 本施策前に解除済（status が unconfirmed 済）のレコードは対象外。Spammer 登録が残る場合は既存の `Admin::SpammersController` から個別解除する。本変更では扱わない。
- **新規・拡張テスト**（`unmark_spam!` の Spammer 解除を2経路の代表で検証）:
  - 既定 author 経路（`spam_author=user`）: 代表として `project_comment_spec`（[:91-](../../spec/models/project_comment_spec.rb#L91)）の `#unmark_spam!` に「spam→unconfirmed で投稿者の Spammer が破棄される」「Spammer 未登録でも冪等」を追加。CardComment / Tag は同一の既定経路を共有するため代表検証で代替する（CardComment は `spec/models/card_comment_spec.rb` が空のため新規テストは追加しない）。
  - override author 経路（最古 contribution の contributor / nil 可）: `card/usage_spec`（[:60-](../../spec/models/card/usage_spec.rb#L60)）・`card/annotation_spec` の `#unmark_spam!` に「作成者の Spammer が破棄される」「`spam_author` が nil（contribution 無し）のとき例外を出さず status のみ `unconfirmed` に戻る」を追加。
  - 共通の状態制約（`unconfirmed` は no-op で冪等 / `approved` は従来どおり例外）は既存テストを維持する。
  - コントローラ: 既存の `Admin::*::SpamsController#destroy` スペックは `unmark_spam!` 呼び出しを検証済みのため、原則修正不要（Spammer 解除はモデル側で担保）。
- **ログ・監査**: 既存の Spammer 登録（`spam_detect!`）が業務監査ログを残していないのと同様、解除（`spam_undetect!`）でも監査ログ要件は要件 2.5 に無いため追加しない。`spam_detection_logs` は検出ログであり本変更の対象外。

## 関連 ADR

- なし。戦略的判断は要件定義書 2.5 に記録済み。戦術的判断（concern への集約・`mark_spam!` との対称性）は本 ChangeSpec とコードコメントで担保する。

## 受け入れ条件

要件定義書 2.5 / 5.5 に対応:

- [ ] コメント（ProjectComment/CardComment）のスパムマーク解除時、投稿者（`user`）の Spammer 登録が解除される
- [ ] カード（Card::Usage/Card::Annotation）のスパムマーク解除時、作成者（最古 contribution の contributor）の Spammer 登録が解除される
- [ ] Tag のスパムマーク解除時、作成者（`user`）の Spammer 登録が解除される
- [ ] ユーザーが複数のスパム投稿で登録されている場合でも、どれか1件の解除で Spammer 登録が外れる
- [ ] Spammer 登録が既に無いユーザーに対する解除でエラーが発生しない（冪等）
- [ ] `spam_author` が特定できない（nil）対象の解除で、エラーを出さず status のみ `unconfirmed` に戻る
- [ ] 解除後に再度スパムマークされたユーザーが Spammer として再登録される
- [ ] プロジェクトのスパム認定取消時に所有者の Spammer 登録が解除される（2.4 実装分の受け入れ確認）
- [ ] 既存の `Admin::SpammersController` による直接削除機能が引き続き動作する

リグレッション防止（本変更で壊してはならない既存挙動）:

- [ ] `unmark_spam!` の状態制約が維持される（`unconfirmed` は no-op・`approved` は例外）
- [ ] `mark_spam!`（Spammer 登録・通知削除・status 変更）が従来どおり動作する
- [ ] スパムマーク解除で、`mark_spam!` 時に削除された未読通知は復元されない（非対称・要件外を固定）
