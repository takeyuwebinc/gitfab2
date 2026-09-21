# ChangeSpec: State を自身の Annotation に変換してしまう不具合の修正と、消えた State の復元

## 変更の目的

State を Annotation に変換する画面が、変換先として変換元自身を選ぶことがある。サーバーはそれを受け付け、State は自身を参照する Annotation（`state_id == id`）になって、プロジェクトのページから消える。本番ではこの形の孤児が 20 件あり、`/admin/annotations` を 500 にした（Sentry: FABBLE-6E）。画面が選んだとおりの State を変換先にするよう直し、サーバー側で自身への変換を拒否し、消えた State を復元する。

前提: 一覧の表示は PR #207 で対処し、本番に反映済みである。PR #207 は master に未マージで、このブランチには含まれない。この変更をデプロイする前に PR #207 を master にマージし、このブランチに取り込む。取り込まずにデプロイすると、一覧の 500 が再発する。

## 現状

本番の調査（2026-09-21、読み取り専用）の結果は次のとおり。

| 項目 | 結果 |
|------|------|
| 孤児（所属 State を解決できない Annotation） | Annotation 31,244 件中 20 件 |
| `state_id` の参照先 | 20 件すべてが自身（`state_id == id`）。NULL、参照先なし、ほかの Annotation を参照する孤児は 0 件 |
| ステータス | 承認済み 19 件、未確認 1 件。スパムは 0 件 |
| 作成時期 | 2016-01 から 2026-08 まで。同じプロジェクトに 4 件、3 件とまとまっている例がある |
| `project_id` | 20 件すべてに残っている |
| 所属プロジェクト | 有効なプロジェクトに 16 件（公開 15、非公開 1）。削除済みプロジェクト（`is_deleted`）に 4 件で、State は 0 件、`states_count` も 0。`spam_hidden_at` は調べていない |
| `states_count` | 全プロジェクトで実際の State 数と一致している |
| タイトルと本文 | タイトルがないものが 3 件ある。本文の長さは全件 4 文字以上で、4 文字のものが 6 件ある（うち 1 件はタイトルもない）。空白だけの本文かどうかは調べていない |
| 孤児に付いたコメント | 0 件 |

コードの現状は次のとおり。

- `Card::Annotation` は `belongs_to :state, class_name: "Card::State"` で所属を決める（[app/models/card/annotation.rb:30](../../app/models/card/annotation.rb#L30)）。STI のため、`state_id` の参照先が `type = 'Card::State'` でないと `state` は nil になる。
- `Card::State#to_annotation!` は渡された State を検査せず、自身の `type` と `state_id` を更新し、`states_count` を 1 減らす（[app/models/card/state.rb:49-55](../../app/models/card/state.rb#L49-L55)）。`project_id` は消さない。`type` は acts_as_list の scope に含まれるため（[state.rb:29](../../app/models/card/state.rb#L29)）、同じプロジェクトの後続の State の `position` が 1 ずつ詰められ、自身の `position` も書き換わる。自身を渡すと `state_id == id` の Annotation になる。ローカルで再現済み。
- `StatesController#to_annotation` は、変換元も変換先も同じプロジェクトの State から探す（[app/controllers/states_controller.rb:61-70](../../app/controllers/states_controller.rb#L61-L70)）。別プロジェクトの State は見つからず 404 になる。両者が同じかは検査しない。
- 画面は、変換先の候補と変換先の要素を別々の値で決めている（[app/assets/javascripts/card.es6:227-262](../../app/assets/javascripts/card.es6#L227-L262)）。
  - 候補の一覧は、jQuery（1.12.4）のデータキャッシュの `position` で作る。この値は `setStateIndex` が画面上の並び順（1 始まり）で書き込む（[card.es6:423-435](../../app/assets/javascripts/card.es6#L423-L435)）。書き込むのは、読み込み時、カードの作成・編集・削除の後、並べ替えの後、変換の後である。
  - 変換先の要素は、DOM の `data-position` 属性で探す（[card.es6:259](../../app/assets/javascripts/card.es6#L259)）。属性はサーバーが描画した DB の `position` で（[app/views/states/_state.html.slim:1](../../app/views/states/_state.html.slim#L1)）、`.data()` による書き込みでは変わらない。
  - 両者がずれると、選んだ候補と違う State が変換先になる。ずれるのは、DB の `position` が 1 からの連番でない場合と、再読み込みせずに State を削除または変換した後である。本番には `position` が `[1, 2, 2, 3, 5, 6]` のプロジェクトがあり、前者は読み込み直後から起きる。並べ替えの確定は属性も書き換えるため（[app/assets/javascripts/card_order.js:48-66](../../app/assets/javascripts/card_order.js#L48-L66)）、ずれの原因にならない。
  - 例: State A・B・C（属性 1・2・3）から A を削除すると、キャッシュは B=1・C=2 になり、属性は 2・3 のまま残る。B を変換しようとして候補の「2: C」を選ぶと、属性が 2 の要素は B 自身である。
  - 候補には、State のテンプレート（[app/views/projects/_templates.html.slim:3](../../app/views/projects/_templates.html.slim#L3)。`id` が -1、`data-position` が 0）も「0: State 0」として混ざる。変換ボタンを有効にする条件（`.state` が 3 個以上）も、テンプレートの 1 個を含めた数である。
  - 要求は `dst_position` も送るが、サーバーは読まない。
- 自身ではない State が変換先になった場合は孤児にならず、意図と違う State の Annotation になる。この件数は調査では分からない。
- 自身への変換の後、画面は変換後の Annotation を取得しにいく。取得先の State がもう存在しないため 404 になり、再読み込みすると State が消えている（コードを読んだ結果で、ブラウザでの再現はしていない）。
- 自身を参照する孤児は、検証を通る更新ができる。Rails 7.1 以降の既定では、`belongs_to` の必須検証は外部キーが NULL か変更されたときだけ走るためである。ローカルの実測で、`approve!`・`unapprove!`・`mark_spam!`・`unmark_spam!`・`to_state!` はいずれも成功した。
- `Card::Annotation#to_state!` は `type`・`project_id`・`position`（State の並びの末尾）を更新し、`states_count` を 1 増やす（[app/models/card/annotation.rb:53-64](../../app/models/card/annotation.rb#L53-L64)）。`state_id` は消さない。プロジェクトの `updated_at` は変えず、通知も送らない。カードの検証（タイトルと本文の両方が空なら無効）は通る必要がある。
- `Card::Annotation` の acts_as_list は `state_id` を scope にする。`state_id` をコールバックを通る更新で NULL にすると、scope の変更として扱われ、`state_id` が NULL の全カード（全プロジェクトの State）の `position` が書き換わる。
- `Project#update_draft!` は検証とコールバックを通る更新で、`updated_at` を変える（[app/models/project.rb:194-196](../../app/models/project.rb#L194-L196)）。
- プロジェクトの `is_deleted` には 2 種類ある。通常の削除（`soft_destroy!`）は State をすべて削除する。スパム認定による非表示（`hide_as_spam!`）は State を残し、`spam_hidden_at` を記録し、取り消せる（[project.rb:163-192](../../app/models/project.rb#L163-L192)）。
- 変換失敗時、画面は応答 JSON の `error` を alert で表示する（[card.es6:307-310](../../app/assets/javascripts/card.es6#L307-L310)）。`ApplicationController` は development 以外で `rescue_from Exception` により 500 を返すため、アクションで捕捉しない例外は JSON の応答にならない。
- JavaScript の自動テストはない。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/assets/javascripts/card.es6](../../app/assets/javascripts/card.es6) | 変換先の候補一覧と、変換の要求 |
| [app/models/card/state.rb](../../app/models/card/state.rb) | `to_annotation!`。State から Annotation への変換 |
| [app/controllers/states_controller.rb](../../app/controllers/states_controller.rb) | `to_annotation` アクション |
| [app/models/card/annotation.rb](../../app/models/card/annotation.rb) | `to_state!`。復元に使う |
| [spec/models/card/state_spec.rb](../../spec/models/card/state_spec.rb) | `to_annotation!` のテスト |
| [spec/controllers/states_controller_spec.rb](../../spec/controllers/states_controller_spec.rb) | `to_annotation` アクションのテスト |

## 変更内容

- **変更（`card.es6`）**: 変換先の候補は、プロジェクトの State の一覧（`#recipe-card-list`）にある State だけから作り、テンプレートを含めない。候補の値に State の id を持たせ、変換元は id で除く。表示する文言（位置とタイトル）は変えない。変換の要求は、選ばれた id をそのまま変換先として送る。変換ボタンを有効にする条件は、一覧にある State が 2 個以上、とする。
- **削除（`card.es6`）**: `data-position` 属性で変換先の要素を探す処理と、`dst_position` の送信。
- **変更（`Card::State#to_annotation!`）**: 変換先が変換元自身の場合と、変換元と別のプロジェクトの State の場合は、何も書き込まずに専用の例外を送出する。後者は画面からは起きない（コントローラが同じプロジェクトに限定している）が、メソッド単体の前提として検査する。
- **変更（`StatesController#to_annotation`）**: 専用の例外をアクション内で捕捉し、422 と既存の形の JSON（`success: false` と `error`）を返す。文言は「変換先に指定できない State です。ページを再読み込みしてやり直してください」とする。存在しない変換先の扱い（404）は変えない。
- **追加（復元。一度きりの操作）**: 本番の孤児 20 件を次のとおり処理する。件数が少ないため rake タスクにはせず、スクリプトを本番で 1 回実行する。スクリプトはリポジトリに残さない。

| 対象 | 処理 |
|------|------|
| 有効なプロジェクトの 16 件 | 元のプロジェクトの State に戻す。位置は State の並びの末尾になる。プロジェクトの検索用テキスト（`draft`）を作り直す。プロジェクトの `updated_at` は変えず、通知も送らない |
| 通常の削除をされたプロジェクトの 4 件 | 削除する。プロジェクトの削除が State をすべて削除しており、その取り残しである |
| 上のどちらの条件にも合わない行 | 処理せず、報告する |

復元の手順は次のとおり。実行は、PR #207 とこの変更を本番に反映した後にする。

1. 対象の id を調査結果の 20 件に固定する。行ごとに、実行時の状態が次の条件に合うことを確かめ、合わない行は処理しない。
   - 共通: `type` が `Card::Annotation`、`state_id == id`、`project_id` がある。
   - 復元する行: プロジェクトが有効（`is_deleted` が偽）。
   - 削除する行: プロジェクトが `is_deleted` で、`spam_hidden_at` が NULL で、State が 0 件。スパム認定で非表示のプロジェクトは取り消せるため、削除の対象にしない。
2. 書き込みをしない実行で、行ごとの処理予定と、復元する行がカードの検証を通るかを出力して確かめる。
3. 行ごとにトランザクションで処理する。処理前の値（`type`・`state_id`・`position`・プロジェクトの `states_count`）を出力して控える。削除する行は、関連（図・添付・貢献者）を含めた内容を先に出力して控える。
   - 復元は、先に `to_state!` を実行し、その後に `state_id` を NULL にする。`state_id` と `draft` の書き換えは、検証・コールバック・タイムスタンプを通らない列単位の更新で行う。順序か手段を誤ると、現状に書いたとおり全プロジェクトの State の `position` が書き換わる。
4. 完了後、孤児が 0 件であること、対象プロジェクトの `states_count` が実際の State 数と一致すること、対象でないプロジェクトの State の `position` が変わっていないことを確かめる。

復元した行は、控えた値を列単位の更新で書き戻し、`states_count` を 1 減らせば元に戻せる。削除した行は元に戻せない。

元の位置は復元できない。変換時に `position` が書き換えられ、もとの値が残っていないためである。オーナーは並べ替えで位置を直せる。

## 影響範囲

- 影響するのは、プロジェクト編集画面の「Convert to Annotation」である。候補からテンプレート由来の「0: State 0」が消え、選んだ State が確実に変換先になる。Annotation から State への変換は、変換先をサーバーが描画したリンクで決めており、同じ問題はない。State の削除と並べ替えは変更しない。
- サーバーの拒否は、修正前の JavaScript を読み込んだままの画面からの要求で起きる。その場合は alert が出て、State は変わらない。
- 復元により、公開中のプロジェクト 15 件と非公開のプロジェクト 1 件で、消えていた State が並びの末尾に再び表示される。State を作成できるのはプロジェクトの編集権限者だけなので、第三者の投稿は含まれない。スライドショー、fork、バックアップにも State として含まれるようになる。
- プロジェクトのページのフラグメントキャッシュは State ごとのキーなので、復元した State は初回から描画される。
- 復元した State は `/admin/annotations` の一覧から消える。削除する 4 件は、図・添付・貢献者の記録も合わせて削除される。
- ログ・記録要件への影響はない。復元はスパム認定の状態を変えない。
- 結合強度評価は省略した。責務の配置は変えず、変換先の指定を位置から id に変える変更と、入力の検査の追加だけである。
- 使い勝手の現実性レビューは省略した。操作手順は変わらない。
- 判断ポイントの比較は省略した。変換先を id で指定する方法は、要求がすでに `dst_state_id` を受け取っているため選択肢が 1 つである。
- 対象外: 次の項目は別の変更として扱う。いずれも本番の孤児 20 件の原因ではない。
  - スパム扱いの Annotation だけを持つ State を変換すると、その Annotation が孤児になる（ローカルで再現済み。本番の実績は 0 件）。
  - 変換された Annotation の `position` が、変換先の既存の Annotation と重複する。
  - `Card.updatable_columns` が `type` を許可しており、更新の要求で型を変えられる。
  - `to_annotation` と `to_state` のルートが、状態を変更するのに `GET` である。
  - 過去に意図と違う State へ変換された Annotation の特定と訂正。
- テスト:
  - [spec/models/card/state_spec.rb](../../spec/models/card/state_spec.rb) の `#to_annotation!` は、変換元と変換先を別々の `create(:state)` で作っており、プロジェクトが別になる。変換先を同じプロジェクトにそろえる。自身と別プロジェクトを拒否するケースを追加する。
  - [spec/controllers/states_controller_spec.rb](../../spec/controllers/states_controller_spec.rb) に、変換先に自身を指定すると 422 と `error` が返るケースを追加する。既存のケース（権限なし、未ログイン、読み取り専用モード）は変更しない。
  - 画面の変更は自動テストがないため、ブラウザで確かめる。

## 関連 ADR

- なし

## 受け入れ条件

自動テスト（RSpec）で確かめる。

- [ ] 変換先に変換元自身を指定して `to_annotation` を要求すると、422 と `error` が返り、State の `type`・`state_id`・`position` とプロジェクトの `states_count` は変わらない。
- [ ] 別プロジェクトの State を渡して `to_annotation!` を呼ぶと、専用の例外が送出され、何も変わらない。
- [ ] 同じプロジェクトの別の State への変換は、従来どおり成功する（`states_count` が 1 減り、変換先の Annotation が 1 増える）。
- [ ] `to_annotation` の既存のテスト（権限なし、未ログイン、読み取り専用モード）が通る。

ブラウザで確かめる。

- [ ] State を削除した直後（再読み込みなし）に別の State を変換すると、候補で選んだ State の Annotation になる。
- [ ] 同じページで 2 回続けて変換すると、2 回とも候補で選んだ State の Annotation になる。
- [ ] `position` に重複や欠番がある State を持つプロジェクトで変換すると、候補で選んだ State の Annotation になる。
- [ ] 候補に「0: State 0」が出ない。State が 1 個のプロジェクトでは、従来どおり変換できない旨の alert が出る。

本番で確かめる（復元の後）。

- [ ] 孤児が 0 件である。
- [ ] 復元した 16 件は、元のプロジェクトのページで State として末尾に表示され、図と添付を保持している。
- [ ] 復元の対象プロジェクトで、`states_count` が実際の State 数と一致し、`updated_at` が変わっていない。
- [ ] 対象でないプロジェクトの State の `position` が変わっていない。
- [ ] 通常の削除をされたプロジェクトの 4 件が削除されている。
