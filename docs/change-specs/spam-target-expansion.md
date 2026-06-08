# ChangeSpec: スパム対応対象の拡大（Card::Usage / Card::Annotation / Tag）

要件: [spam-moderation-enhancement.md](../requirements/spam-moderation-enhancement.md) 2.1
進捗管理: [2026-06-08-spam-moderation-enhancement-status.md](../workflow/2026-06-08-spam-moderation-enhancement-status.md)

## 変更の目的

既存のスパムマーク機構（ProjectComment / CardComment）を、ログイン済ユーザーがオーナー・コラボレーター以外でも投稿できる **Card::Usage / Card::Annotation / Tag** にも拡大し、運用で手動対応できる範囲を広げる（要件 2.1）。

## 現状

- スパムマーク機構は `SpamCommentable` concern に集約されている（[spam_commentable.rb](../../app/models/concerns/spam_commentable.rb)）。
  - `enum :status, { unconfirmed: 0, approved: 1, spam: 2 }`
  - `mark_spam!` は `user.notifications_given.destroy_all` → `user.spam_detect!` → `status: :spam` を `with_lock` 内で実行。**`user` 関連を前提**。
  - `unmark_spam!` は `approved` を拒否し `spam → unconfirmed` のみ許可（status 変更のみ。Spammer 解除は未実装）。
- include しているのは `ProjectComment` / `CardComment` のみ。両者とも `belongs_to :user`。
- **Card::Usage / Card::Annotation**: `cards` テーブル（STI: State/NoteCard/Usage/Annotation で共有）。`user_id` も `status` も持たない。作成者は `contributions`（`contributor_id`）経由で、カード作成時に最古の contribution が付与される（[usages_controller.rb](../../app/controllers/usages_controller.rb) `update_contribution`、annotations 同様）。
- **Tag**: `tags` テーブル。`belongs_to :user`（作成者）。`status` を持たない。
- 公開非表示は `not_spam` スコープ（Rails enum が自動生成。Rails 6.0 以降の標準機能で 7.2 でも有効）+ `visible_*` 関連で実現（`Card#visible_comments`、`Project#visible_project_comments`）。Usage/Annotation/Tag は未対応で、`project.usages` / `state.annotations` / `project.tags` がそのまま公開表示される。
- admin の認可は `Admin::ApplicationController` の `before_action` による `is_system_admin?` 一律ガードのみ（CanCanCan のリソース認可は使っていない）。
- admin は `Admin::Comments::BaseController` が名前空間から `comment_class` を導出する薄い抽象。`SpamsController`（create=`mark_spam!` / destroy=`unmark_spam!`）、`SpamBatchesController`（`unconfirmed.where(created_at <= ?).mark_spam!`）を提供。派生（ProjectComments/CardComments）は継承のみ（[base_controller.rb](../../app/controllers/admin/comments/base_controller.rb)）。
- `User#spam_detect!` は冪等（既に spammer なら何もしない）。`Spammer` は `user_id` ユニーク。
- マイグレーションは `add_column ..., :status, :integer, default: 0, null: false, comment: "確認ステータス 0:未確認 1:承認済み 2:スパム"` の形（[20250111071932_add_status_to_comments.rb](../../db/migrate/20250111071932_add_status_to_comments.rb)）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/models/concerns/spam_commentable.rb` | スパムマーク機構の本体（リネーム・一般化対象） |
| `app/models/card_comment.rb` / `app/models/project_comment.rb` | 既存 includer（include 名の更新） |
| `app/models/card/usage.rb` / `app/models/card/annotation.rb` | 追加対象（include + 作成者特定） |
| `app/models/tag.rb` | 追加対象（include） |
| `app/models/project.rb` / `app/models/card/state.rb` | `visible_*` 関連の追加先 |
| `app/controllers/admin/comments/*` | admin 抽象（汎用化対象） |
| `config/routes.rb` | admin スパムルートの追加 |
| `app/controllers/projects_controller.rb` ほか公開表示箇所 | `visible_*` への置換 |

## 変更内容

- **変更（リネーム）**: `SpamCommentable` → 汎用名 `SpamMarkable` に変更。`CardComment` / `ProjectComment` の include を更新（挙動は不変）。
- **変更（一般化）**: concern に `spam_author` を導入（デフォルトは `user`）。`mark_spam!` を `spam_author` 基準に変更し、`spam_author` が nil の場合は通知削除・Spammer 登録をスキップして status 変更のみ行う。既存コメントは `spam_author == user` のため挙動不変。
  - 注: `unmark_spam!` 時の Spammer 自動解除は要件 2.5 の範囲。本 ChangeSpec では `spam_author` の導入までを行い、解除ロジック自体は追加しない。
- **追加（データ）**: `add_column :cards, :status`（Usage/Annotation 用。共有テーブルのため State/NoteCard 行にも列が追加されるが既定 `unconfirmed` で挙動不変。既存コードに Card/State/NoteCard の `status` 参照が無いことを確認済み＝副作用なし）/ `add_column :tags, :status`。いずれも `default: 0, null: false, comment` 付き。
- **追加（モデル）**:
  - `Card::Usage` / `Card::Annotation` に `SpamMarkable` を include し、`spam_author` を「`contributions` のうち `created_at` 最古のレコードの `contributor`（無ければ nil）」と定義。
  - `Tag` に `SpamMarkable` を include（`spam_author` はデフォルトの `user`）。
- **追加（公開非表示）**: `visible_usages`（Project）/ `visible_annotations`（Card::State）/ `visible_tags`（Project）を `-> { not_spam }` で追加し、公開表示箇所を `visible_*` に置換する（projects#show・slideshow・`states/_state`・`projects/_basic_informations`・各 JSON jbuilder・`Project#generate_draft` の全文検索 draft 等）。
- **追加（admin）**: 既存 admin 抽象を汎用名へ一般化し、Usage/Annotation/Tag 用の一覧（`status` フィルター）・スパムマーク/解除（create/destroy）・一括スパムマーク（spam_batch）のコントローラ・ビュー・ルートを追加する。
- **追加（一括スパムマーク）**: 指定日時以前の `unconfirmed` レコードを一括で spam に変更（`approved`/`spam` は対象外。既存 `SpamBatchesController` と同型）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | ADR |
|---|------------|--------|-----|
| 1 | 作成者参照を持たないカードでスパムマークの「投稿者」をどう供給するか | concern に `spam_author` を導入し多態化（デフォルト `user`、Card は最古 contributor を override） | 起票せず（後述） |
| 2 | カード作成者の定義 | `contributions` の `created_at` 最古の `contributor`。無ければ nil（Spammer 登録スキップ） | 同上 |
| 3 | concern 名と admin 抽象 | 汎用名へリネーム（`SpamCommentable` → `SpamMarkable`、admin の Comments 名空間も汎用化） | 同上 |

**ADR を起票しない理由**: 上記はいずれも既存の concern + override という Rails 標準パターンの範囲内の拡張であり、アーキテクチャパターンの変更を伴わないため（doc-orchestration の合意に基づきインライン記録）。設計判断を伴う ADR は要件 2.3（スパム認定の非破壊化）に集約する。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `SpamMarkable` → includer の作成者参照 | Model(2)/同一(1)・`user` 具象前提 NG寄り | Functional(1)/同一(1)・`spam_author` 契約 OK | override 可能な契約化で改善 |
| 2 | Card のスパムマーク責務 → `contributions`（最古） | （新規） | Model(2)/同一(1) OK | カード作成者の特定。許容 |
| 3 | 公開表示 → `usages`/`annotations`/`tags` 直接参照 | Model(2)/同一(1) | Model(2)/同一(1) | `visible_*` 経由へ。既存 `visible_comments` と同型 |

許容する不均衡: なし（新たな不均衡は生じず、#1 はむしろ改善）。

## 影響範囲

- **モデル**: concern リネームに伴い `CardComment` / `ProjectComment` の include 名を更新。`Card::Usage` / `Card::Annotation` / `Tag` に include 追加。既存コメントの挙動は不変。
- **マイグレーション**: `cards.status`、`tags.status` の 2 本。`cards` は STI 共有のため State/NoteCard 行にも列が増える（既定値で挙動不変）。
- **公開表示**: 以下の点在箇所を `visible_*` へ置換する（置換漏れがあると spam が一般画面に残る）。
  - Card::Usage: `app/models/project.rb`（`visible_usages` 追加）、`app/controllers/projects_controller.rb`（`@usages`）、`app/views/projects/_usages.html.slim`、`app/views/usages/*.json.jbuilder`
  - Card::Annotation: `app/models/card/annotation.rb`（`not_spam` 利用）、`app/models/card/state.rb`（`visible_annotations` 追加）、`projects_controller.rb`（show の includes / slideshow の `@cards` 構築）、`app/views/states/_state.html.slim`、`app/views/projects/_recipe_cards.html.slim` 経由の `recipe_cards_list.json.jbuilder`
  - Tag: `app/models/project.rb`（`visible_tags` 追加）、`app/views/projects/_basic_informations.html.slim`、`app/views/projects/_tags.html.slim`、`app/models/project.rb#generate_draft`（全文検索 draft）
  - 注: 作成系 JSON（`usages/create` 等）は投稿者本人への応答であり公開一覧ではないため、表示制御の主対象は一覧・show・slideshow・draft。
- **admin**: 既存 Comments 抽象を汎用化し、Usage/Annotation/Tag の一覧（`status` フィルター）・spam（create/destroy）・spam_batch コントローラとビュー、ルートを追加。ルートは既存コメントと同型で以下を想定:
  ```ruby
  # namespace :admin 内
  resources :usages, only: :index do
    resource :spam, only: [:create, :destroy], module: :usages
  end
  namespace :usages do
    resource :spam_batch, only: :create
  end
  # annotations / tags も同型
  ```
  認可は `is_system_admin?` ガードで既存と同じく ability 追加は不要。
- **counter_cache**: `mark_spam!` は status 変更のみで `usages_count` 等を減算しない（既存コメントの `comments_count` と同じ挙動）。`usages_count` は公開表示に未使用、`comments_count` も既存から spam を含む値のため、本変更で新たな表示ズレは生じない。
- **テスト**:
  - 既存 `SpamCommentable` の spec をリネーム。既存コメントの mark/unmark 挙動が不変であることを担保。
  - 新規: `spam_author` の単体テスト（Card=最古 contributor / contribution 無し=nil / Tag=user）。Usage/Annotation/Tag の mark_spam!（Spammer 登録）・unmark_spam!（spam→unconfirmed のみ・approved 拒否）・一括スパムマーク。
  - 公開表示で spam レコードが非表示になる request/system spec。
- **対象外（本 ChangeSpec では扱わない）**:
  - `unmark_spam!` 時の Spammer 自動解除（要件 2.5）。
  - スパマーが作成した Usage/Annotation/Tag を作成時に自動 spam 化する挙動（コメントの `build_from` 相当）。要件 2.1 に明記がなく、別途必要性を確認する。

## ログ変更

該当なし（既存 `mark_spam!` の `Rails.logger` 出力・SpamDetectionLog の体系に変更を加えない。状態変更は管理画面操作だが、本要件では新規の監査ログ項目を追加しない）。

## 関連 ADR

なし（理由は「採用した実装パターン」を参照。設計判断の ADR は要件 2.3 に集約予定）。

## 受け入れ条件

- [ ] 管理画面から Card::Usage をスパムマーク／解除できる
- [ ] 管理画面から Card::Annotation をスパムマーク／解除できる
- [ ] 管理画面から Tag をスパムマーク／解除できる
- [ ] Usage / Annotation / Tag の管理画面一覧を `status` でフィルターできる
- [ ] スパムマーク時、投稿者（Card=最古 contributor、Tag=user）が Spammer として登録される
- [ ] 作成者を特定できない Card（contribution 無し）でも、エラーにならず status のみ spam に変更される
- [ ] スパムマークされた Usage / Annotation / Tag が一般ユーザー画面（show・slideshow・タグ表示・全文検索 draft）で非表示になる
- [ ] 指定日時以前の `unconfirmed` レコードを一括でスパムマークできる
- [ ] 一括スパムマークは `approved` および `spam` 状態のレコードを対象に含めない
- [ ] `spam` 状態から `unconfirmed` への遷移のみ許可される
- [ ] `approved` 状態からの直接のスパム解除操作は拒否される
- [ ] 既存コメント（ProjectComment / CardComment）のスパムマーク／解除の挙動が変わらない
