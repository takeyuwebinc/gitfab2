# 0001_スパム認定監査ログにおける操作者の捕捉方式

## ステータス

承認済み

## 日付

2026-06-08

## 信頼度

中〜高 — 現状のスパム手動認定の呼び出し経路が全て admin リクエスト文脈に限定されていることはコード調査で確認済みで、現時点の正しさは高い。一方、採用案の弱点（リクエスト外呼び出しで操作者が nil、RSpec のテスト間リセット漏れ、インラインジョブによる `Current` リセット）はこのコードベースが現時点で踏んでいない経路であり、実装・テストでの作り込みに依存するため確信度を中〜高とする。

## 再評価条件

- `SpamMarkable#mark_spam!`/`unmark_spam!` または `SpamDesignationService`/`SpamDesignationRevocationService` を、admin リクエスト以外（バックグラウンドジョブ、rake タスク、バッチ）から呼ぶ経路が追加された場合。`Current.admin` が nil になり操作者を記録できないため、案A（操作者を引数で渡す）への移行を検討する。
- 認定処理のトランザクション内でインラインジョブ（`:inline` アダプタ等）が実行され、`CurrentAttributes` がリクエスト途中でリセットされる事象が確認された場合。
- 監査ログの記録漏れ（操作者 nil の記録）が運用上問題化した場合。

## コンテキスト

スパム手動認定の監査ログ（だれが・いつ・どれをスパム認定したか）を新設する。記録すべき「操作者」は管理者ユーザーであり、`current_user`（`is_system_admin?`、すなわち `authority == 'admin'`）で識別される。

### 現状の問題点

- 操作者（`current_user`）はコントローラ層にしか存在しない。
- 記録対象である状態変更は複数のドメイン経路に分散している:
  - `SpamMarkable#mark_spam!` / `#unmark_spam!`（ProjectComment / CardComment / Card::Usage / Card::Annotation / Tag）。一括処理は `find_each(&:mark_spam!)` でドメインメソッドを直接呼ぶ。
  - `SpamDesignationService` / `SpamDesignationRevocationService`（Project のスパム認定 / 取消）。
- これらのドメインメソッド・サービスは操作者を引数で受け取っていない。

### 制約条件

- 一括処理 `find_each(&:mark_spam!)` は1件ずつドメインメソッドを呼ぶため、対象を特定した1件1ログを取るには記録点がドメイン側にあるか、ループの書き換えが必要。
- 自動スパム化経路（`ProjectComment.build_from` の `status = :spam if user.spammer?` 等）は「人」による振り分けではないため、監査ログ（操作者記録）の対象外とする。これらは既存の `SpamDetectionLog`（自動検出ログ）の領域。
- 現状、上記ドメインメソッド・サービスの呼び出しは全て admin コントローラのリクエスト文脈に限定される（コード調査で確認）。

## 決定

`ActiveSupport::CurrentAttributes` に操作者（`current_user`）を載せ、状態変更を検知するモデルコールバックで監査ログを記録することを決定する。

### 実装方針

1. admin リクエスト文脈で操作者を `Current`（CurrentAttributes サブクラス）に設定する。設定箇所は `Admin::ApplicationController` の before_action とし、admin 配下の全操作で一貫して利用できるようにする。
2. 記録対象モデルのコールバックで、スパム認定/取消に相当する状態遷移を検知し、操作者・操作種別・対象を監査ログに記録する。一括処理 `find_each(&:mark_spam!)` は各レコードの `update!` ごとにコールバックが発火するため、ループを書き換えずに1件1ログが得られる。
3. **操作者が nil の場合は監査ログを記録しない。** これにより自動スパム化経路（操作者が存在しない）は自然に対象外となり、「人による振り分けのみ記録する」という要件を満たす。
4. 既存のドメインメソッド・サービスのシグネチャ（`mark_spam!`、`SpamDesignationService.call` 等）は変更しない。

## 結果

### ポジティブな影響

1. **影響範囲の最小化**
   - 既存のドメインメソッド・サービスの呼び出し側を改修せずに済む。一括処理 `find_each(&:mark_spam!)` もそのままで1件1ログが取れる。

2. **記録ロジックの集約**
   - 記録処理がモデルコールバックに集約され、複数のコントローラ・サービスに分散しない。

3. **自動経路の自然な除外**
   - 操作者が存在しない自動スパム化経路は `Current.admin` が nil となり、記録されない。要件と実装が自然に一致する。

### ネガティブな影響・トレードオフ

1. **暗黙のグローバル状態への依存**
   - 操作者の伝搬が引数ではなく `CurrentAttributes` 経由のため、コードを読んだだけでは操作者の出所が追いにくい。
   - 対策: 操作者の設定箇所を `Admin::ApplicationController` の before_action 一箇所に限定し、設定経路を単純化する。

2. **リクエスト外呼び出しでの操作者欠落**
   - 将来、ジョブや rake から認定処理を呼ぶと `Current.admin` が nil になり、操作者を記録できない（または記録漏れになる）。
   - 対策: 「nil 時は記録しない」ルールを明示。リクエスト外経路の追加を再評価条件に設定し、その時点で案Aへの移行を検討する。

3. **テスト容易性の低下**
   - モデルスペックでコールバックを検証するには `Current.admin` の明示セットアップが必要。
   - さらに rspec-rails はテスト間で `CurrentAttributes` を自動リセットしない（Rails 標準の `ActiveSupport::TestCase` は行う）。リセット漏れは監査ログのアサーションを偽陽性・フレーキーにする。
   - 対策: テストスイート全体で `CurrentAttributes` をリセットする共通設定（`ActiveSupport::CurrentAttributes::TestHelper` 相当）を導入する。リクエストスペックでは自然に操作者が設定されるため、エンドツーエンドの検証を主とし、モデルスペックではヘルパで `Current` を設定する。

## 代替案

### 案A: ドメイン/サービスに操作者を引数で渡す

**概要**: `mark_spam!(by:)`、`SpamDesignationService.call(projects, by:)` のように操作者を明示的に渡し、ドメイン/サービス内で記録する。

**メリット**:
- 操作者の出所が明示的でコードから追える。
- テストが容易。リクエスト外（ジョブ・rake）からでも操作者を渡せる。

**デメリット**:
- 全エントリポイントとドメイン/サービスのシグネチャ変更が必要。
- 一括処理 `find_each(&:mark_spam!)` を per-item で `by` を渡す形に書き換える必要がある。
- ドメインが「操作者」概念に依存し、結合が増える。

**却下理由**: 影響範囲が最も大きく、既存の一括処理・全エントリポイントの改修を伴う。現状リクエスト外呼び出しが存在せず、案Aの主メリット（リクエスト外での操作者伝搬）が現時点で不要なため、コストに見合わない。

### 案B: コントローラ層で記録する

**概要**: `current_user` を持つコントローラ層で監査ログを直接記録する。ドメインは純粋なまま。

**メリット**:
- ドメインを操作者概念から切り離せる。
- 操作者の出所が明示的。

**デメリット**:
- 記録コードが6つのエントリポイント（コメント系 記録/取消/一括、Project 認定/一括/取消）に分散し、エントリポイント追加時の記録漏れリスクが最も高い。
- 一括処理は `find_each` 内で per-item 記録に書き換えが必要。
- 自動経路との一貫性（記録する/しない）を手動で管理する必要がある。

**却下理由**: 記録点の分散による漏れリスクが高く、保守コストが大きい。記録の集約という目的に反する。

## 参考資料

- [ADR-0002: 監査ログのデータモデル（汎用 AuditLog + Delegated Types）](0002-audit-log-data-model-delegated-types.md)（監査ログの格納構造。本ADRと直交し両立する）
- ChangeSpec: スパム記録ログ（`docs/change-specs/spam-moderation-audit-log.md`）の判断ポイント JP-1
- `app/models/concerns/spam_markable.rb` — `mark_spam!` / `unmark_spam!`
- `app/services/spam_designation_service.rb`、`app/services/spam_designation_revocation_service.rb`
