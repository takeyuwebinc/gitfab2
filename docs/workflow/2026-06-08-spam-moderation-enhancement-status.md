# ドキュメントワークフロー進捗

## プロジェクト情報

- **ワークフローID**: spam-moderation-enhancement
- **プロジェクト名**: スパム運用機能の拡充
- **ステータス**: 進行中
- **開始日**: 2026-06-08
- **判定**: フル文書化ワークフローではなく **ChangeSpec ルート**で対応する

## ワークフロー規模の判定（Phase 1.2）

doc-orchestration の change-spec 誘導条件をすべて満たすため、フル文書化ワークフロー（要件定義〜ファクトチェック）は実施しない。

- 既存機能（`SpamCommentable` / `SpamDesignationService` / `Spammer` / Admin 機能）の**変更・拡張**であり、新規機能開発ではない
- 要件定義書（[spam-moderation-enhancement.md](../requirements/spam-moderation-enhancement.md)）は既に完成（v1.0 / 2026-04-17）しており、要件・機能設計の一式作成は不要
- 影響範囲が既知のコンポーネントに限定される
- 同要件の 2.2（キーワード検出の正規化）は既に「ChangeSpec → 実装 → 廃棄」で処理済みであり、プロジェクトの確立された進め方がある

ユーザー合意（2026-06-08）:
- 対象範囲 = 既存要件の未実装分（2.1 / 2.3 / 2.4 / 2.5）
- 進め方 = 要件ごとに ChangeSpec を作成 → 実装 → 廃棄

## ワークフロー進捗

- [x] Phase 1: インベントリと計画
- [x] Phase 2: 要件定義（既存文書を使用 / 完了済み）
- [x] Phase 3: 用語集（対象外 — 要件定義書の用語定義セクションを使用）
- [x] Phase 4: 機能設計（対象外 — ChangeSpec ルートのため不要）
- [x] Phase 5: 調査報告書 & ADR（対象外 — 必要時は change-spec 内で ADR 連携）
- [x] Phase 6: ファクトチェック（対象外）
- [x] Phase 7: 完了レビュー（ChangeSpec ルートのため doc-orchestration はここで終了）

## 要件の実装状況（コード確認結果 / 2026-06-08）

| 要件 | 内容 | 状況 | 根拠 |
|---|---|---|---|
| 2.1 | スパム対応対象の拡大（Card::Usage / Card::Annotation / Tag） | **実装済**（3a7f38cb 〜 e59c8454） | `SpamCommentable`→`SpamMarkable` 一般化、Usage/Annotation/Tag 対応、Admin 管理フロー統一、自動スパム化・既存データ移行まで完了。ChangeSpec 廃棄済み（b3ba84fa） |
| 2.2 | キーワード検出の正規化 | 実装済 | コミット f3c8e7a6、ChangeSpec 廃棄済（754d02ff） |
| 2.3 | スパム認定の非破壊化 | **実装済**（94f0c158） | `designate` を `hide_as_spam!`（is_deleted=true ＋ `spam_hidden_at` 記録）へ置換。通常削除と区別するため `spam_hidden_at` カラムを追加。ChangeSpec 未廃棄（2.4 と一括クリーンアップ予定） |
| 2.4 | スパム認定の取消機能 | **実装済**（9327179f / 7efa7b61） | `unhide_as_spam!`・取消サービス・`Admin::Projects::SpamsController`・index の status フィルタ。一覧は `spam_hidden_at` 有りのみ。ChangeSpec 未廃棄（2.3 と一括クリーンアップ予定） |
| 2.5 | スパマー登録の自動解除 | 未実装 | `SpamMarkable#unmark_spam!` は status 戻しのみで Spammer 解除フックなし。2.4 で `User#spam_undetect!`（Spammer 破棄）を新設済み |
| 2.6 | エラー処理 | — | 2.1〜2.5 に付随する横断要件。各 ChangeSpec に内包 |

## ChangeSpec 分割計画と推奨実装順（実装引き継ぎ）

実装は development-start スキルが担当する。以下は doc-orchestration が依存関係から導いた**初期案**であり、実装時に最終決定される。各 ChangeSpec は change-spec スキルで作成する。

| 推奨順 | ChangeSpec（要件） | 依存（先行） | 主な改修対象 | 状況 |
|-------|------------------|------------|------------|------|
| 1 | 2.1 スパム対応対象の拡大 | — | `SpamCommentable`→`SpamMarkable` リネーム＋`spam_author` 多態化、Card::Usage / Card::Annotation / Tag、Admin コントローラ・ビュー・一括処理 | **完了**。実装 3a7f38cb / b23f6780 / 750a9672 ＋ 追加 f7e2cd95 / 4a293600 / e59c8454。ChangeSpec 廃棄済み（b3ba84fa） |
| 2 | 2.3 スパム認定の非破壊化 | — | `SpamDesignationService`（破壊的処理の停止）、`spam_hidden_at` 追加 | **完了**。実装 94f0c158（spec 97ea2127 / 25bad267）。ChangeSpec 未廃棄（2.4 と一括クリーンアップ予定） |
| 3 | 2.4 スパム認定の取消機能 | 2.3 | 取消用 Admin コントローラ・一覧・取消処理 | **完了**。実装 9327179f / 7efa7b61（spec cb0dea8e / efad3da1）。一覧は `spam_hidden_at` 有りのみ（施策前分は識別不能のため対象外）。ChangeSpec 未廃棄（2.3 と一括クリーンアップ予定） |
| 4 | 2.5 スパマー登録の自動解除 | 2.1, 2.4 | `SpamCommentable#unmark_spam!`、プロジェクト取消経路 | 全解除経路（コメント/Usage/Annotation/Tag/プロジェクト取消）を横断するため、対象（2.1）と取消経路（2.4）が揃ってから着手 |

- **順序の根拠**:
  - 2.3 → 2.4: スパム認定の取消（2.4）は非破壊化（2.3）後の認定でのみ完全復元できるため、2.3 が前提。
  - 2.1, 2.4 → 2.5: 自動解除（2.5）は共有 concern `unmark_spam!` と各解除経路を横断改修する。新対象（2.1）の解除経路とプロジェクト取消（2.4）が揃ってから着手すると一度の改修で全経路を網羅できる。
  - 2.1 と 2.3 は相互独立。1↔2 の順序は入れ替え可能。

## ADR 候補（任意）

- 2.3 の「スパム認定時の破壊的処理を停止し、論理削除のみとする（取消可能性と引き換えに関連データを保持）」は設計判断を含む。要件定義書には記録済みだが、恒久的な判断記録が必要なら change-spec 内で adr-documentation 連携を行う。

## 備考

- **進捗同期（2026-06-08 / 2.3・2.4 完了）**: 2.3（非破壊化＋通常削除と区別する `spam_hidden_at` カラム追加）と 2.4（取消機能：`unhide_as_spam!`・取消サービス・Admin UI、認定済み一覧はキーワード検索可）を実装完了。**次は推奨順 4 の 2.5「スパマー登録の自動解除」**。2.3/2.4 の ChangeSpec は結合ペアとして一括クリーンアップ予定のため未廃棄（クリーンアップ／2.5 着手の順序は未確定）。
- **進捗同期（2026-06-08）**: 2.1 は追加実装（f7e2cd95 既存データの承認済み移行 / 4a293600 管理フローのコメント統一 / e59c8454 スパム投稿者の Usage/Annotation/Tag 自動スパム化）まで完了し、ChangeSpec は b3ba84fa で廃棄済み。コードで 2.3 / 2.4 / 2.5 の未実装を再確認済み。**次は推奨順 2 の 2.3「スパム認定の非破壊化」**から着手する。
- 用語集は未作成。要件定義書「4. 用語定義」セクションを用語の権威ソースとして各 ChangeSpec で参照する。
- 2.1 の設計上の注意: `SpamCommentable#mark_spam!` は `user`（投稿者）関連を前提とする。Card::Usage / Card::Annotation / Tag の作成者参照が `user` と異なる場合、concern の一般化が必要（2.1 ChangeSpec で検討）。
- 完了後、この進捗管理ファイルと各 ChangeSpec・実装台帳はクリーンアップ対象（git 履歴には残る）。
