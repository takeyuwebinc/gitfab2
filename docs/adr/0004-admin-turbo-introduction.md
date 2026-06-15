# 0004_管理画面への Turbo 導入方式（turbo-rails + sprockets、admin スコープ限定）

## ステータス

承認済み

## 日付

2026-06-15

## 信頼度

中 — 導入手段（turbo-rails + sprockets）と「admin レイアウトでのみ読み込み公開サイトに波及させない」スコープ方針はユーザーが明示承認済み。一方、本決定の主目的である「モデレーション操作（POST→redirect→同一一覧URLへのGET）後に Morphing + Scroll preservation でスクロール位置が保持される」ことは Turbo 8 のページリフレッシュ Morphing の仕様に基づく見込みであり、本プロジェクトのリダイレクトフロー・ページネーション・flash 表示下での発火は実機検証が残る。

## 再評価条件

- Turbo を admin に限定読み込みしても、admin → 公開ページ遷移や共有パーシャル経由で公開サイトの jQuery/coffee/hyperapp 挙動に干渉が出た場合。
- Morphing がモデレーションのリダイレクトフローで発火せず、スクロール保持の目的が達成できない場合（同一URL判定されない、flash やページネーションで morph 差分が破綻する等）。この場合は Turbo Stream による部分更新方式へ切り替えを検討する。
- 将来 admin 以外にも Turbo を広げる必要が生じ、admin 限定スコープの前提が崩れた場合。
- importmap-rails や propshaft へアセット基盤を移行した場合（require 手段の前提が変わる）。

## コンテキスト

管理画面では、コメント・Usage・Annotation・タグ等のモデレーションで「スパムにする／未承認に戻す（承認取消・スパム取消）」操作を行う。これらは `button_to` / `link_to`（`method:` + `data: { confirm }`、現状 rails-ujs が処理）で送信され、サーバは同一一覧へ `redirect_to` する。結果として全画面リロードが発生し、一覧の途中で操作するとスクロール位置が先頭にリセットされ、連続したモデレーション作業の効率が落ちる。

この体験を改善するため、管理画面に Turbo を導入し、ページリフレッシュ時の Morphing と Scroll preservation でスクロール位置を保持する。

### 現状の問題点

- Turbo/Hotwire は未導入（gem・node_module ともに無し）。
- 管理画面レイアウト [`app/views/layouts/admin.html.slim`](../../app/views/layouts/admin.html.slim) は `admin.js`（中身は [`//= require rails-ujs`](../../app/assets/javascripts/admin.js) のみ）を読み込む。モデレーション操作は rails-ujs 経由で送信され、応答は全画面リロードでスクロールがリセットされる。
- 公開サイトは jQuery（`jquery-rails`）/ hyperapp（`app/frontend/like.ts`）に依存する別バンドルを使用する（`coffee-rails` gem も宣言されている）。Turbo Drive をグローバルに有効化すると公開サイトの既存挙動（クリック・フォーム送信の横取り）を壊すリスクがある。

### 制約条件

- アセット基盤は sprockets 4.2.1 ＋ sprockets-rails 3.5.2 ＋ jsbundling-rails（webpack、entry は `like.ts` のみ）の併用。importmap-rails・propshaft は未導入。Rails 7.2。
- 公開サイトのバンドル（jQuery/hyperapp 等）には Turbo を一切載せない。Turbo の影響は admin 配下に閉じること。
- 管理画面のモデレーションは「同一一覧URLへのリダイレクト」で完結しており、この導線は維持する（サーバ側の再描画＋クライアント側の差分適用で実現する）。

### 結合分析

本決定はレイアウト・アセット層への横断的追加であり、既存のドメインモデル・コントローラの責務配置や結合関係（強さ×距離）は変更しない。新たなドメイン結合点を作らないため、均衡結合の悪化はない。むしろ Turbo を admin レイアウトに限定することで「Turbo への依存」を admin コンテキスト内に閉じ、公開サイトとの距離（異コンテキスト）を保つ。

## 決定

管理画面への Turbo 導入は、**turbo-rails gem を追加し、sprockets の admin バンドルにのみ Turbo アセットを require して、admin レイアウトでのみ読み込む**方式を採用する。Turbo は公開サイトのバンドルには載せない。

Morphing と Scroll preservation は、admin レイアウトの `<head>` に Turbo のページリフレッシュ用 meta（リフレッシュ方式＝morph、スクロール＝preserve）を出力して有効化する。モデレーション操作後の「同一一覧へのリダイレクト」を Turbo がページリフレッシュとして検出し、差分適用（morph）でスクロール位置を保持することを狙う。

なお Turbo のページリフレッシュ判定は **pathname（パス）ベースの一致**で行われる（公式ハンドブックには明文化されておらず、Turbo の実装挙動に基づく）。モデレーションのリダイレクト先は同一一覧パス（例: `/admin/card_comments`）であり、pathname が一致すれば morph 対象になる見込み。

ただし表示内容と保持スクロール位置を整合させるため、**モデレーション操作後のリダイレクトは現在のページ・フィルタ（`page`・`status` 等）のクエリパラメータを維持する**ことを本決定に含める。現状はリダイレクト時に `status` のみを維持し `page` を落としているため（ビューの `button_to` も `status` のみ渡す）、操作後にページ先頭の内容へ戻りスクロール位置と食い違う。クエリを維持することで、morph 後も操作対象と同じページ・絞り込みが表示され、スクロール保持が意味を持つ。

### 実装方針

1. `turbo-rails` を依存に追加する。Turbo アセットは admin バンドル（sprockets）にのみ require し、公開サイトのバンドルには追加しない。
2. Turbo の読み込みは admin レイアウトに限定する。公開サイトのレイアウト・バンドルからは参照しない（スコープを admin に閉じる）。
3. admin レイアウトの `<head>` に、ページリフレッシュ時の挙動を「morph + scroll preserve」とする meta を出力する。
4. rails-ujs と Turbo の二重処理を避ける。管理画面のモデレーション操作の確認ダイアログは Turbo 方式（`data-turbo-confirm`）へ移行し、`method:` 指定のリンク/ボタンが Turbo とrails-ujs の双方に処理されない状態にする。admin から rails-ujs を外すか Turbo と整合させるかは、移行時にモデレーション系ビュー（[`admin/card_comments/index`](../../app/views/admin/card_comments/index.html.slim) 他）の動作確認をもって確定する。
5. admin から公開ページへ遷移するリンクなど、Turbo Drive に扱わせたくない導線は `data-turbo="false"` で個別に除外する。
6. モデレーション操作のリダイレクトで現在のページ・フィルタのクエリ（`page`・`status` 等）を維持する。具体的には、モデレーション系ビューの `button_to`（承認・未承認に戻す・一括スパム）に現在の `page` を渡し、対応コントローラ（[`Admin::Comments::ApprovalsController`](../../app/controllers/admin/comments/approvals_controller.rb)・[`SpamsController`](../../app/controllers/admin/comments/spams_controller.rb)・[`SpamBatchesController`](../../app/controllers/admin/comments/spam_batches_controller.rb) 等）の `redirect_to` で受け取ったクエリを差し戻す。リダイレクト先 pathname を一覧と一致させたうえで、表示ページ・絞り込みを操作前と揃える。
7. 受け入れ確認として、一覧の途中（2ページ目以降を含む）でスパム化／未承認化を行った後に、同じページ・絞り込みが表示されスクロール位置が保持されること、確認ダイアログが二重に出ないこと、公開サイトの挙動に変化がないことを実機で検証する。

## 結果

### ポジティブな影響

1. **スクロール位置の保持によるモデレーション効率の向上**
   - 一覧途中での連続操作で先頭に戻らなくなり、対象の見失いと再スクロールが解消される。

2. **公開サイトへの影響をゼロに保てる**
   - Turbo を admin バンドル・admin レイアウトに限定するため、Turbo スクリプト自体が公開ページに載らない。jQuery/coffee/hyperapp との競合リスクを構造的に排除する。

3. **Rails 標準経路に乗る**
   - turbo-rails 採用により、将来 turbo_stream など Hotwire の標準機能を必要に応じて利用できる素地ができる（今回のスコープでは Morphing のみ）。

### ネガティブな影響・トレードオフ

1. **rails-ujs と Turbo の責務境界の管理が必要**
   - `data-confirm` / `method:` の処理主体が二者に分かれると二重処理・確認ダイアログ重複が起きうる。
   - 対策: 管理画面の確認を `data-turbo-confirm` に統一し、移行時にモデレーション系ビューで二重処理が無いことを検証する（実装方針4・6）。

2. **Morphing 発火がフレームワークのリフレッシュ検出に依存する**
   - スクロール保持は「同一URLへのリダイレクトをページリフレッシュとして検出し morph する」Turbo の挙動に依存する。flash 表示やページネーション位置で差分適用が想定通り働かない可能性がある。
   - 対策: 受け入れ条件で実機検証し、発火しない場合は Turbo Stream による部分更新へ切り替える（再評価条件に記載）。

3. **アセット基盤の前提に結びつく**
   - sprockets への require を前提とするため、将来 importmap/propshaft へ移行すると読み込み方法の見直しが必要。
   - 対策: スコープを admin に閉じ、移行時の影響範囲を admin バンドルに限定する。

## 代替案

### 案A: webpack(jsbundling) の entry に Turbo を追加し admin 専用バンドルをビルド

**概要**: 既存 webpack の entry に admin 用エントリ（`@hotwired/turbo` を import）を追加し、admin レイアウトでのみ読み込む。

**メリット**:
- gem 依存を増やさない。
- ビルドパイプラインが webpack に一本化される部分がある。

**デメリット**:
- turbo-rails が提供する Rails 連携（turbo_stream のビューフォーマット、ヘルパー等）が使えない。
- admin 用エントリと TypeScript ビルド設定の追加保守が必要。

**却下理由**: 既存アセットの大半は sprockets 管理で、Turbo も sprockets に載せる方が現行構成と親和的。将来 Hotwire 標準機能へ広げる際に turbo-rails の連携が有効。webpack は現状 `like.ts` 単一用途に留めるのが保守上単純。

### 案B: importmap-rails を新規導入して Turbo を読み込む

**概要**: importmap-rails を導入し、Turbo を importmap 経由で配信する（Rails 7 の Hotwire 標準構成）。

**メリット**:
- ビルド不要で Turbo を導入でき、Rails の現行デフォルト構成に沿う。

**デメリット**:
- 既存に無いアセット基盤（importmap）を新規に持ち込み、sprockets+webpack と三重管理になる。
- スコープを admin に限定する制御が、グローバルな importmap 配信と相性が悪く追加の工夫が要る。

**却下理由**: 新しいアセット基盤の導入は今回の小さな目的（admin のスクロール保持）に対して過大。三重管理の保守コストに見合わない。

### 案C: 現状維持（Turbo を導入しない）

**概要**: Turbo を導入せず、rails-ujs + 全画面リロードのまま据え置く。

**メリット**:
- 追加依存・移行作業が無い。

**デメリット**:
- スクロールリセットの問題が解消されず、モデレーション作業の非効率が残る。

**却下理由**: 本要望（スクロール位置保持）を満たせない。JS で個別にスクロール位置を保存・復元する手段もあるが、操作ごとの実装が散在し保守性が低い。

## 実装上の補足

実装時、Turbo Drive を admin 全体で有効化すると、既存の rails-ujs 依存リンク（`link_to method:`/`remote:` を使う features・announcements・featured_items）や admin から公開サイトへ遷移するリンクのクリックが Turbo に横取りされ、`data-method`/`remote` や公開ページの JS 初期化が壊れることが判明した。本ADRの再評価条件「admin→公開ページ干渉が出た場合」に沿い、次の方式で Drive スコープを細分化して採用した。

- Turbo Drive は admin でデフォルト無効にする（`Turbo.session.drive = false`）。
- スクロール保持が必要なモデレーション系の `button_to` には `form: { data: { turbo: true } }` を指定し、**`<form>` 要素**に `data-turbo="true"` を付けて個別に opt-in する（`button_to` の `data:` は `<button>` に付き、Turbo はフォーム送信を `<form>` の属性で判定するため、`<button>` への付与では効かない）。
- morph + scroll preserve は、この opt-in したフォーム送信後のページリフレッシュ（同一一覧パスへのリダイレクト）に適用される。実機検証で、一覧途中での承認/未承認/一括スパム操作後にスクロール位置が保持されること（全画面リロードが起きず、操作した行が消える分の微小なズレに留まること）を確認済み。

**Turbo の読み込み方式**: turbo-rails の `turbo.js` は ESM（`export`）であり、sprockets の `//= require` でクラシックスクリプトとして連結すると構文エラーで Turbo がロードされない。このため admin レイアウトで `javascript_include_tag "turbo", type: "module"` として ESM 読み込みし、直後の `type="module"` スクリプトで `Turbo.session.drive = false` を実行する（module は記述順に実行されるため、無効化は turbo.js の自己起動後に走る）。`admin.js`（sprockets, classic）は `rails-ujs` のみを担う。

このため、将来 admin の別画面で Turbo の挙動（Drive ナビゲーション・morph 等）を使う場合は、対象の `<form>`/リンク要素に `data-turbo="true"` を明示する必要がある。

## 参考資料

- [`app/views/layouts/admin.html.slim`](../../app/views/layouts/admin.html.slim) — 管理画面レイアウト。Turbo の ESM module 読み込み・Drive 無効化・morph/preserve meta を配置。
- [`app/assets/javascripts/admin.js`](../../app/assets/javascripts/admin.js) — sprockets バンドル。`rails-ujs` のみ（Turbo は ESM のため別途 module 読み込み）。
- [`app/views/admin/card_comments/index.html.slim`](../../app/views/admin/card_comments/index.html.slim) ほかモデレーション系ビュー — `form: { data: { turbo: true } }` による opt-in と `data-turbo-confirm` 化の対象。
- Turbo Handbook — Page Refreshes（Morphing / `turbo-refresh-method` / `turbo-refresh-scroll`）: https://turbo.hotwired.dev/handbook/page_refreshes
