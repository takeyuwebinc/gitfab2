# ChangeSpec: 管理者権限の付与・剥奪の認可を Ability に集約しボタンを無効化する

## 変更の目的

管理者権限の付与・剥奪が可能かの認可を `Ability` クラスで表現し、ビューでは認可されない操作のボタンを無効化する。現状は可否に関わらず常に有効なボタンを描画し、不可の操作は POST 後に flash で初めて弾かれるため、操作前に可否が分からない。

## 現状

- ページレベル認可（操作者がシステム管理者か）は [admin/application_controller.rb:4-13](../../app/controllers/admin/application_controller.rb#L4-L13) の `before_action` が担い、`Ability` は使っていない。
- [ability.rb](../../app/models/ability.rb) に管理者権限の付与・剥奪に関するルールは存在しない。`User` に対しては `can :manage, User, id: user.id`（自分自身の管理のみ）のみ。
- 管理不能状態を防ぐ業務ルール（自己剥奪 `:self`、最後の1名の剥奪 `:last_one`、状態不変の冪等扱い）は [admin_authority_change_service.rb:47-63](../../app/services/admin_authority_change_service.rb#L47-L63) が**実行時**に判定する。`:last_one` は管理者集合を `FOR UPDATE` ロックした同一トランザクション内で評価し、同時剥奪による0名化を直列化して防ぐ。サービスのコメントは「認可（操作者が管理者であること）は呼び出し側の責務」と明記。
- [admin/users/index.html.slim:26-29](../../app/views/admin/users/index.html.slim#L26-L29) は現在の管理者状態でのみ分岐（管理者→「剥奪」、それ以外→「付与」）し、**可否に関わらず常に有効なボタン**を描画する。自己・最後の1名の「剥奪」も押下でき、POST 後の flash で弾かれる。
- CanCanCan 採用済み。ビューでの `can?` 利用は確立（例 [groups/edit.html.slim:16](../../app/views/groups/edit.html.slim#L16)）。`CanCan::AccessDenied` は `render_401` へ（[application_controller.rb:11](../../app/controllers/application_controller.rb#L11)）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/models/ability.rb](../../app/models/ability.rb) | CanCanCan の認可ルール定義。付与・剥奪 action を追加する |
| [app/models/user.rb](../../app/models/user.rb) | `is_system_admin?` を持つ。最後の1名判定の読み取り述語を追加する |
| [app/services/admin_authority_change_service.rb](../../app/services/admin_authority_change_service.rb) | 付与・剥奪の状態遷移・誤操作防止・監査記録。可否述語を追加し、ロック内の実行時ガードは維持する |
| [app/controllers/admin/users/admin_authorities_controller.rb](../../app/controllers/admin/users/admin_authorities_controller.rb) | 付与（create）・剥奪（destroy）受付。`authorize!` を追加する |
| [app/views/admin/users/index.html.slim](../../app/views/admin/users/index.html.slim) | ユーザー一覧と操作ボタン。`can?` で可否を判定しボタンを無効化する |

## 変更内容

- **追加（読み取り述語）**: `User#last_system_admin?` — 「自身がシステム管理者で、かつ他にシステム管理者が存在しない」を返す。Ability・コントローラの事前判定が参照する単一の読み取り述語。判定に用いる管理者数の問い合わせは**対象ユーザー非依存（管理者総数の COUNT）**とし、一覧の各行で評価しても同一 SQL となるよう実装する（N+1 緩和の前提、後述）。
- **追加（可否述語）**: `AdminAuthorityChangeService` に可否判定の述語を追加する。
  - 付与可否: 操作者がシステム管理者であること。
  - 剥奪可否: 操作者がシステム管理者であり、対象が操作者自身でなく、対象が最後のシステム管理者でないこと（`User#last_system_admin?` を参照）。
- **追加（認可ルール）**: `Ability` に `User` を対象とする付与・剥奪の2 action を追加し、判定を上記の可否述語に委譲する。
- **変更（コントローラ）**: `create`/`destroy` で、対象解決後に対応する action を `authorize!` する。認可されないリクエスト（偽装 POST 等）は `CanCan::AccessDenied`→`render_401`。
- **変更（ビュー）**: 「付与」「剥奪」ボタンを `can?` で判定し、不可の場合は**無効化**して描画する（非表示ではなく `disabled`）。操作者自身の行の「剥奪」は無効になる。「付与」はこの画面では操作者が常に管理者のため実質常時有効だが、`can?` 経由で統一する。`button_to` では `disabled` を html_options 位置の引数として渡す（現状の呼び出しは html_options ハッシュを明示していないため引数位置の調整が必要）。
- **維持**: `AdminAuthorityChangeService` のロック内の `:self`・`:last_one` 実行時ガードは削除せず維持する（レースセーフな最終防御）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 認可の適用範囲（ビューのみ / ビュー＋サーバ強制） | ビュー無効化＋コントローラ `authorize!`（多層防御） | なし（既存 CanCanCan パターンの範囲内） |
| 2 | 自己・最後の1名ルールの置き場所（重複許容 / 述語共有） | 述語を共有して集約（`User#last_system_admin?` と可否述語を Ability・コントローラが参照） | なし |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | ビュー → 認可判定 | なし（常時有効） | Functional(1)/presentation→domain OK | `can?` で action シンボルという契約に依存。許容 |
| 2 | 「最後の管理者を守る」ドメインルールの散在 | Service 1箇所 | 共有述語 `last_system_admin?` を Ability・コントローラが参照（Functional(1)） | 読み取り述語を一元化。Service のロック内ガードは race 安全性のため意図的に残す（重複ではなく別責務） |
| 3 | ビュー内 `can?(:revoke…, user)` の N+1 | — | 対象ID非依存の同一 COUNT SQL のため AR クエリキャッシュ（リクエスト単位）で1回に集約。`is_system_admin? &&` 短絡で非管理者は問い合わせない | 述語の COUNT を対象非依存にすることが緩和の前提。許容 |

許容する不均衡: ロックを伴う `:last_one` の実行時判定はサービスに残すため、可否ルールの完全な一元化は不可能。Ability・コントローラ用の読み取り述語（`last_system_admin?`）とサービスのロック内ガードは、目的（事前判定 / レースセーフな確定）が異なる別責務として併存させる。

## 影響範囲

- **コントローラの挙動変更**: 認可されない剥奪リクエスト（自己剥奪・偽装 POST 等）は、従来の「302 リダイレクト＋flash alert」から **401（`render_401`）** に変わる。通常フローではボタンが無効化されるため到達しない。
- **サービスの flash エラーの到達性**: `:self` は `authorize!` が先に弾くため、コントローラ経由では実質到達不能になる（サービス内のガードは多層防御として保持）。`:last_one` は同時剥奪のレース時のみ `authorize!` を通過しサービスが弾くため、flash として引き続き到達しうる。
- **既存テストの修正**: [spec/controllers/admin/users/admin_authorities_controller_spec.rb](../../spec/controllers/admin/users/admin_authorities_controller_spec.rb) の「操作者自身を剥奪しようとした場合」「最後の管理者を剥奪しようとした場合」は、期待を `flash[:alert]` から 401 応答へ変更する。
- **ビュー描画テストへの波及**: [spec/controllers/admin/users_controller_spec.rb](../../spec/controllers/admin/users_controller_spec.rb) は `render_views` で一覧ビューを実描画するため、ビューへの `can?` 追加で `Ability` 評価が走る。本リポジトリに request/system spec は存在せず、この controller spec が唯一のビュー描画経路。回帰がないことを確認し、操作者自身の剥奪ボタンが無効化される検証もここ（`render_views` 付き controller spec）で追加する。
- **既存テストへの非影響**: [spec/services/admin_authority_change_service_spec.rb](../../spec/services/admin_authority_change_service_spec.rb) はサービス挙動が不変のため修正不要。
- **新規テスト**: `Ability` の付与・剥奪 action のテスト（新規 `spec/models/ability_spec.rb` 等）、`User#last_system_admin?` のテストを追加する。
- **監査ログ**: 既存の監査記録（サービスが実状態変更時に記録）に変更なし。認可で弾かれた操作は状態変更が起きないため記録もされない（現状どおり）。

## 関連 ADR

- なし（既存 CanCanCan パターンの範囲内のため ADR 起票不要と判断）

## 受け入れ条件

- [ ] `User#last_system_admin?` が、唯一のシステム管理者に対して true、複数管理者が存在する場合や非管理者に対して false を返す。
- [ ] `Ability` で、操作者がシステム管理者のとき他ユーザーへの付与が許可される。
- [ ] `Ability` で、操作者自身への剥奪が拒否される。
- [ ] `Ability` で、最後のシステム管理者への剥奪が拒否される。
- [ ] `Ability` で、複数管理者が存在する場合の他管理者への剥奪が許可される。
- [ ] ユーザー一覧で、操作者自身の行の「剥奪」ボタンが `disabled` で描画される（`render_views` 付き controller spec で検証）。
- [ ] 認可されない剥奪リクエスト（自己剥奪等）をコントローラへ直接送ると 401 が返り、権限が変更されない。
- [ ] 付与（create）側の `authorize!` は、ページレベル認可と同条件（操作者がシステム管理者）のため通常 401 経路を持たず、認可済み操作者の付与は通過する。
- [ ] 冪等な no-op（既に管理者への付与・既に一般ユーザーへの剥奪）は `authorize!` で 401 にならず、従来どおり成功扱い（`changed: false`）で一覧へリダイレクトする。
- [ ] 認可される付与・剥奪リクエストは従来どおり成功し、一覧へリダイレクトして flash を表示する。
- [ ] 同時剥奪で最後の1名になるレースは、サービスのロック内ガードにより引き続き拒否される。
