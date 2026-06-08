# ChangeSpec: スパム記録ログ（管理操作の監査ログ）

## 変更の目的

スパムを「だれが・いつ・どれを」記録/取消したかを残す監査ログを新設する。既存の「スパム検出ログ」(`spam_detection_logs`) は自動検出によるブロックの記録専用で、管理者が手動で振り分けた操作（操作者・日時・対象）は一切記録されていない。管理機能の操作説明責任・不正監査のためにこれを補う。

## 現状

- スパム手動認定は、状態変更（`status` enum / `spam_hidden_at`）として残るのみで、**操作者・操作日時・対象を結びつける記録は存在しない**。
- 監査ログの既存パターンは無い（`ProjectAccessLog` はアクセス解析用）。本変更で新規パターンを確立する。
- 手動認定のエントリポイントと経路:

| 操作 | エントリポイント | ドメイン処理 | 対象 |
|------|----------------|------------|------|
| コメント系 記録(単体) | `Admin::Comments::SpamsController#create` | `SpamMarkable#mark_spam!` | ProjectComment / CardComment / Card::Usage / Card::Annotation / Tag |
| コメント系 取消(単体) | `Admin::Comments::SpamsController#destroy` | `SpamMarkable#unmark_spam!` | 同上 |
| コメント系 記録(一括) | `Admin::Comments::SpamBatchesController#create` | `find_each(&:mark_spam!)` | 同上 |
| プロジェクト認定(単体/一括) | `Admin::ProjectsController#destroy` / `#batch_spam` | `SpamDesignationService` → `Project#hide_as_spam!` | Project |
| プロジェクト認定取消 | `Admin::Projects::SpamsController#destroy` | `SpamDesignationRevocationService` → `Project#unhide_as_spam!` | Project |

- 操作者 `current_user`（`is_system_admin?` = `authority == 'admin'`）は `Admin::ApplicationController` でのみ識別される。
- 自動スパム化経路（`ProjectComment.build_from` / `CardComment.build_from` の `status = :spam if user.spammer?`、`SpammerRestriction`）は「人」による振り分けではなく、操作者を持たない。これらは検出ログの領域であり、本監査ログの対象外。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/models/concerns/spam_markable.rb` | `mark_spam!` / `unmark_spam!`（コメント系の状態遷移） |
| `app/models/project.rb` | `hide_as_spam!` / `unhide_as_spam!`（`spam_hidden_at` 遷移） |
| `app/services/spam_designation_service.rb` / `spam_designation_revocation_service.rb` | プロジェクト認定/取消 |
| `app/controllers/admin/application_controller.rb` | admin 認可の before_action（操作者の設定箇所） |
| `app/models/spam_detection_log.rb` / `app/controllers/admin/spam_detection_logs_controller.rb` | 既存検出ログ。命名・閲覧画面の踏襲元 |

## 変更内容

- **追加**: 汎用監査ログ基盤を Delegated Types で新設（ADR-0002）。
  - 共通テーブル `audit_logs`: 操作者ID（NOT NULL）、委譲参照（`auditable_type` / `auditable_id`）、発生日時。`AuditLog` は `belongs_to :operator`（User）と `delegated_type :auditable, types: %w[SpamModerationAudit]` を持つ。
  - 種別別テーブル `spam_moderation_audits`: 操作種別（記録/取消）、対象種別、対象ID。`SpamModerationAudit` は共通 `Auditable` 責務（`has_one :audit_log, as: :auditable`）を持つ。
  - スパムは最初の委譲先。他の監査種別は種別別テーブル/モデルの追加と `types` への登録で拡張する。
- **追加**: 操作者を保持する `CurrentAttributes`（`Current.admin`）。`Admin::ApplicationController` の before_action で `current_user` を設定する。
- **変更**: `SpamMarkable` にコミット前のトランザクション内コールバック（`after_save` / `before_commit` 等）を追加。コミットされる `status` が spam に遷移した時を「記録」、spam→未確認に遷移した時を「取消」と判定し、`Current.admin` が存在する場合のみ `SpamModerationAudit`（＋委譲元 `AuditLog`、`operator = Current.admin`）を生成する。spam を含まない遷移（`approved→未確認` 等の `unapprove!`）は記録しない。状態変更と同一トランザクション内で記録し、記録失敗時は状態変更ごとロールバックする（原子性を担保。`after_commit` ではこの保証が得られないため用いない）。
- **変更**: `Project` に同種のコールバック（状態変更と同一トランザクション内）を追加。`spam_hidden_at` の遷移（nil→値 = 記録、値→nil = 取消）を検知して記録する。`hide_as_spam!`/`unhide_as_spam!` は `SpamDesignationService`/`...RevocationService` の `transaction do` 内で実行されるため、記録も同一トランザクションに含まれる。
- **追加**: 管理画面の読み取り専用一覧（`Admin::AuditLogsController#index` とビュー、ルート）。`audit_logs` を新しい順で表示し、スパム種別の詳細（操作種別・対象）を委譲先から表示する。既存の `Admin::SpamDetectionLogsController` の構成に倣う。
- 一括処理 `find_each(&:mark_spam!)` は各 `update!` でコールバックが発火するため、ループを書き換えずに対象ごと1件の記録が得られる。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| JP-1 | 操作者の捕捉とログ記録位置（コントローラ層 / ドメイン引数渡し / グローバル暗黙捕捉） | `CurrentAttributes` で暗黙捕捉し、モデルコールバックで記録。`Current.admin` nil 時は記録しない | [ADR-0001](../adr/0001-spam-moderation-audit-operator-capture.md) |
| JP-2 | 監査ログのデータモデル（スパム専用テーブル / 汎用＋Delegated Types / ポリモーフィック＋JSON / STI） | 汎用 `AuditLog` ＋ `delegated_type`。スパムを最初の委譲先とする | [ADR-0002](../adr/0002-audit-log-data-model-delegated-types.md) |

## 結合への影響

| # | 結合点 | 変更前 | 変更後 強さ/距離 | 備考 |
|---|--------|--------|----------------|------|
| 1 | 監査ログ記録コールバック → `Current.admin`（グローバル状態） | 無（新規） | Integration(4)/異コンテキスト(3) NG | ADR-0001 で評価した許容不均衡。nil 時は記録しない運用で誤記録を抑制 |
| 2 | SpamMarkable/Project コールバック → 監査ログ記録責務 | 無（新規） | Functional(1)/同一コンテキスト(2) OK | 公開記録責務のみに依存 |
| 3 | `Admin::ApplicationController` → `Current.admin` | 既存 before_action のみ | Model(2)/同一コンテキスト(2) OK | 設定箇所を一点に限定 |
| 4 | `SpamModerationAudit` → 対象（content_type+id）、`AuditLog` → User（操作者） | 無（新規） | Model(2)/同一コンテキスト(2) OK | `SpamDetectionLog` の content_type 方式を踏襲、緩い参照 |
| 5 | `AuditLog` ⇄ `SpamModerationAudit`（`delegated_type` 委譲） | 無（新規） | Functional(1)/同一モジュール(1) OK | 同一監査基盤内の設計上の委譲。ADR-0002 |

許容不均衡: CP1。解消には案A（操作者を引数で渡す）への移行が必要だが、現状リクエスト外からの認定処理呼び出しが無く（コード確認済み）、優先度は低い。詳細は ADR-0001。

## 影響範囲

- **DBマイグレーション2件追加**: `audit_logs`（共通）と `spam_moderation_audits`（種別別）テーブル新設（デプロイ/ロールバック手順に影響）。
- **モデル新設**: `AuditLog`（`delegated_type :auditable`）、`SpamModerationAudit`、共通 `Auditable` 責務（concern）。汎用監査基盤として他種別に拡張される前提（ADR-0002）。
- **ルート追加**: `admin/audit_logs#index`（既存 `spam_detection_logs` の構成に倣う）。
- **`Current`（`ActiveSupport::CurrentAttributes` サブクラス）クラス新設**: `admin` 属性を保持。
- `SpamMarkable` を include する5モデル（ProjectComment / CardComment / Card::Usage / Card::Annotation / Tag）にコールバックが追加される。既存のスパム記録/取消の挙動自体は変えない（記録が副作用として増えるのみ）。
- `Project` モデルにコールバックが追加される。
- `Admin::ApplicationController` の before_action 追加は admin 配下全コントローラに影響するが、`Current.admin` の設定のみで既存の認可挙動は変えない。
- 既存のスパム関連コントローラ（記録/取消/一括/プロジェクト認定）は呼び出し側の変更なしで監査ログが記録される。
- テストへの影響:
  - 新規: `AuditLog` / `SpamModerationAudit` モデルspec（`delegated_type` の委譲・`operator` 関連）、コールバック挙動（記録/取消/一括で対象ごと `AuditLog`＋`SpamModerationAudit` を1組、操作者 nil で記録なし）、プロジェクト認定/取消の記録、管理画面一覧の request spec。
  - 既存: スパム記録/取消の request spec に監査ログ生成の検証を追加。
  - テスト基盤: rspec-rails の構成によってはテスト間で `CurrentAttributes` がリセットされず操作者が混入しうるため、リセットを保証する設定（`ActiveSupport::CurrentAttributes::TestHelper` 相当）の確認・導入を行う（ADR-0001 参照）。

## ログ変更

### 追加

- **監査ログ：スパム手動認定の記録/取消**（汎用監査ログ `AuditLog` の最初の種別 `SpamModerationAudit`）
  - 発生タイミング：管理者がコンテンツ（コメント系/Project）をスパム記録、またはその取消を行い、状態遷移がコミットされた時。`Current.admin` が存在する場合のみ。
  - 記録項目：操作者ID・操作日時（共通 `AuditLog`）、操作種別（記録/取消）・対象種別・対象ID（種別別 `SpamModerationAudit`）。
  - 用途：管理操作の説明責任、誤認定・不正の監査、スパム判定履歴の追跡（監査部門・運用担当が参照）。

### 監査・記録要件

- **目的**：管理機能の操作監査（だれがスパム認定したか）。
- **根拠**：現時点で明確な法令上の根拠なし。社内の操作説明責任・不正監査が動機。
- **保存期間**：無期限保持（自動削除しない）。記録は軽量（ID主体）で運用負荷は小さい。将来、法令・運用要件が生じた場合に見直す。
- **参照者**：システム管理者、運用担当。

### PIIマスキング方針

| 項目 | マスキングパターン | 理由 |
|------|------------------|------|
| 操作者ID | そのまま記録 | 監査の目的そのもの（操作者の特定が必要）。内部識別子で、外部公開しない |
| 対象種別・対象ID | そのまま記録 | 内部識別子のみ。本文等のコンテンツ実体は記録しない |

- コメント本文等の自由記述・個人情報は監査ログに保存しない（対象は種別＋IDの参照のみ）。スパム認定は非破壊（`status` / `spam_hidden_at`）で対象実体が残るため、必要時は参照で辿れる。

### 影響範囲（ログ関連）

- 新規ログのため既存 BI・分析基盤・運用ツールへの影響なし。
- 既存の `spam_detection_logs`（検出ログ）には一切手を入れない。両ログは目的が異なる（検出＝自動ブロック記録、本ログ＝手動操作の監査）。

## 関連 ADR

- [ADR-0001: スパム認定監査ログにおける操作者の捕捉方式](../adr/0001-spam-moderation-audit-operator-capture.md)
- [ADR-0002: 監査ログのデータモデル（汎用 AuditLog + Delegated Types）](../adr/0002-audit-log-data-model-delegated-types.md)

## 受け入れ条件

- [ ] 管理者がコメント系コンテンツをスパム記録すると、`AuditLog`（操作者・日時）＋ `SpamModerationAudit`（操作種別=記録・対象種別・対象ID）が1組記録される
- [ ] スパム記録を取消すると、操作種別=取消で `AuditLog`＋`SpamModerationAudit` が1組記録される
- [ ] 一括スパム記録で N 件処理すると、対象ごとに合計 N 組の監査ログが記録される
- [ ] プロジェクトのスパム認定（単体/一括）とその取消が監査ログに記録される
- [ ] 自動スパム化（spammer による投稿の自動 spam 化）、および `approved→未確認`（`unapprove!`）では監査ログが記録されない
- [ ] 監査ログの insert を失敗させた場合、状態変更（`status` / `spam_hidden_at`）もロールバックされ、記録と状態が乖離しない
- [ ] 管理画面の一覧に操作者・操作種別・対象種別・対象ID・日時が新しい順で表示される
- [ ] 一覧は読み取り専用で、作成/更新/削除のルート・操作を持たない
- [ ] テスト間で `CurrentAttributes` がリセットされ、操作者の混入が起きない
