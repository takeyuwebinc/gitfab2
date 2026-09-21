# ChangeSpec: カードの並べ替えで position が壊れる不具合の修正

## 変更の目的

レシピの State と Annotation を並べ替えて確定すると、指定と違う並びで保存されることがある。State が 4 枚以上のプロジェクトで起き、position の重複と欠番が残る。並べ替えの結果が常に指定どおりになり、position が 1 から始まる連番に保たれるようにする。

## 現状

並べ替えは、画面上の全カードに 1 から順の position を振り直し、id と position の組を一括で送る方式である。State は `projects#change_order`、Annotation は State ごとの `states#update` が受け取り、どちらも nested attributes でカードを 1 件ずつ保存する。

`Card::State` と `Card::Annotation` は `acts_as_list`（0.9.19）を使う。この gem は、position が変わったカードを保存した後、同じ position を持つ他のカードが DB にあると、移動前と移動後の position の間にある他のカードを DB 上で 1 つずつずらす。移動前の position にはメモリ上の値を使う。ずらす処理はメモリ上のカードを更新しないため、一括保存では 2 件目以降のメモリ上の値が DB の値とずれ、ずらす範囲を誤る。

連番の State を全順列で並べ替えた実測の結果は次のとおりである。既存のスペックは 3 枚を逆順にする 1 通りだけを検証しており、この不具合を検出できない。

| State の枚数 | 順列の数 | 失敗（並びが指定と違う、または position が連番でない） | うち並びが指定と違う |
|---|---|---|---|
| 3 | 6 | 0 | 0 |
| 4 | 24 | 2 | 0 |
| 5 | 120 | 24 | 7 |

本番の読み取り調査（2026-09-21）の結果は次のとおりである。

- State の position が重複しているプロジェクトは 33 件で、最終更新は 2014 年から 2026 年に分散している。スパム対策の導入（2026 年）より前から発生している
- State を持つ 3,485 プロジェクトのうち 99 件で、position が 1 から始まる連番になっていない
- Annotation の position が重複している State は 239 件ある
- 読み取り専用モードは無効だった

本番に実在した重複の形（`[1,2,3,5,6,6,7]` など 5 種類）から並べ替えを始めると、現行コードでは 150 回中 11〜87 回で並びが指定と違った。連番の 6 枚から始めた場合は 150 回中 6 回だった。試行の半分は 1 枚だけ動かす並べ替え、残りは無作為な並べ替えである。

このほか、現状には次の性質がある。

- 表示順は `ORDER BY position` だけで決まる。position が同じカードの順序は DB に任されている
- 一括保存では、position が変わるカードが検証を通る。そのうち 1 枚でも title と description が両方とも空だと、並べ替え全体が 400 で失敗する
- 整数として解釈できない position（`"abc"` や空文字）は 0 として保存され、リクエストは成功する
- プロジェクトまたは State に属さないカードの id を含むリクエストは、属性の代入の時点で 404 になり、何も書き込まれない
- State のフラグメントキャッシュは、State、State の Annotation、表示するコメント、閲覧者から作るキーと、各レコードの `updated_at` に基づくバージョンで無効化される。キャッシュされる HTML は `data-position` と見出し「State N」を含む。`cards.updated_at` は秒精度である
- `states#update` は、Annotation の並べ替えでも、State 自身を検証して保存し、State の title と description をスパムキーワードで検査する。成功すると、操作者を State の contributor に加え、プロジェクトの `updated_at` を更新し、更新通知を送る
- `states#update` に `annotations_attributes` を送る画面は、Annotation の並べ替えフォームだけである。このフォームには送信の失敗を利用者に知らせる処理がない（State の並べ替えフォームにはある）
- スパムと判定された Annotation は画面に出ないため、Annotation の並べ替えのリクエストに含まれない
- `projects#change_order` は保存のたびに検索用テキスト（draft）を再生成する。プロジェクトの `updated_at` が更新されるのは、draft の内容が変わった場合だけである。既存のスペックは `updated_at` の更新を期待しているが、スペック内で draft が変わるために通っている

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/controllers/projects_controller.rb` | `change_order` で State の並べ替えを受け取る。プロジェクト詳細とスライドショーで State を表示順に読む |
| `app/controllers/states_controller.rb` | `update` で Annotation の並べ替えを受け取る |
| `app/models/card/state.rb` | State。`acts_as_list` の scope はプロジェクトと type。表示順の scope と Annotation の関連を持つ |
| `app/models/card/annotation.rb` | Annotation。`acts_as_list` の scope は State。表示順の scope を持つ |
| `app/models/project.rb` | `accepts_nested_attributes_for :states` と draft の再生成を持つ |
| `app/assets/javascripts/card_order.js` | 画面上の並びから id と position の組を作って送る（変更しない） |
| `app/views/projects/_recipe_cards.html.slim` | State の並べ替えフォームと、State のフラグメントキャッシュ（変更しない） |
| `app/views/states/_state.html.slim` | Annotation の並べ替えフォーム（変更しない） |
| `app/views/projects/_recipe_cards_list.html.slim` | カード一覧で State を表示順に読む（変更しない） |
| `app/services/backup.rb` | バックアップで State を `order(:position)` で並べる |
| `spec/controllers/projects_controller_spec.rb` | `change_order` の既存スペック（3 枚の逆順のみ）。`states#update` の `annotations_attributes` を扱う既存スペックはない |

## 変更内容

- **追加**: カードの並びを確定する責務を追加する。並べ替える範囲の全カード（State ならプロジェクトの全 State、Annotation ならスパムを含む State の全 Annotation）と、リクエストの id と position の組を受け取り、次の手順で並びを確定する
  1. 範囲の全カードを現在の表示順（position、id の昇順）に並べる
  2. リクエストに含まれるカードを、要求された position の昇順に並べる。position が同じカードは現在の表示順に従う
  3. リクエストに含まれないカードは、現在の表示順で直前にある「リクエストに含まれるカード」の直後に置く。直前にそのようなカードがなければ先頭に置く。同じ場所に置くカードが複数あれば、現在の表示順を保つ
  4. 得られた並びに 1 から順の position を振る。position が変わるカードだけ、position と `updated_at` を書き込む
  5. 書き込みは 1 つのトランザクションで行い、`acts_as_list` のコールバックと検証を通さない列単位の更新にする
  - 次の場合は、何も書き込まずに拒否する。範囲に属さない id を含む場合は「見つからない」として、position が整数の表記でない場合（空文字、nil、小数、数字以外）と同じ id を複数回含む場合は「不正なリクエスト」として、呼び出し元が区別できる形で拒否する。負の整数と 0 は受け付け、並びのキーとして使う
- **変更**: `projects#change_order` は nested attributes による保存をやめ、上の責務に State の並びの確定を任せる。`states_attributes` が空のリクエストでは責務を呼ばない。成功時は現状どおり draft を再生成し、加えてプロジェクトの `updated_at` を必ず更新する。応答は、成功時 `{ success: true }`、「見つからない」は 404、「不正なリクエスト」と権限なしは 400 と `{ success: false }` にする
- **変更**: `states#update` は、`annotations_attributes` に position が含まれるとき、次の順で処理する。`annotations_attributes` を含まないリクエストでは責務を呼ばない
  1. State の属性を代入する前に、id の所属と position の表記を確かめる。「見つからない」は 404、「不正なリクエスト」は 400 と `{ success: false }` で拒否し、State、contributor、Annotation のどれも書き込まない
  2. position を除いた属性で State を現状どおり検証、スパムキーワード検査、保存する
  3. State の保存と Annotation の並びの確定を 1 つのトランザクションで行う
  - position を除くのは `states#update` の中だけにする。`Card::Annotation` の更新可能な列の定義は変えない
  - 応答の形、contributor の追加、プロジェクトの `updated_at` の更新、更新通知は変えない
- **変更**: State と Annotation の表示順に id の昇順を第 2 キーとして加える。対象は、両モデルの表示順の scope、State が持つ Annotation の関連 2 つ、バックアップの State の並びである
- **追加**: 並びの確定で `acts_as_list` のコールバックを通さない理由と、`updated_at` を書き込む理由を、コードコメントに残す（コードレビューで確認する）

既存の重複と欠番は一括では補正しない。表示順は第 2 キーで確定し、position は次に並べ替えたときに連番へ戻る。

### 新規に追加する責務の配置

| # | 責務 | コンテキスト | 配置先 | 所有するルール・閾値・派生値 |
|---|------|------------|--------|--------------------------|
| 1 | カードの並びを確定する責務 | レシピカード | Model（カード） | 要求された position の順に範囲の全カードを 1 からの連番へ振り直す規則。リクエストに含まれないカードを直前のカードの直後に残す規則。受け付ける position の表記の規則 |

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 並べ替えの実現方式 | リクエストの形を変えず、サーバー側で範囲の全カードを振り直す | なし（理由はコードコメントに残す） |
| 2 | 既存の重複データの扱い | 表示順に第 2 キーを加え、一括補正はしない | なし |
| 3 | Annotation の並べ替えの入口 | `states#update` のままにする | なし |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | 一括の並べ替え（`ProjectsController#change_order`、`StatesController#update` の `annotations_attributes`）→ `acts_as_list` のコールバック | Functional(3)/同一コンテキスト(2) △ | なし | 「全カードの並びを送る」リクエストと、1 件の移動を前提にしたコールバックの暗黙の依存を除く。1 件だけ position を変える経路の依存は残る（変更しない） |
| 2 | 両コントローラー → カードの並びを確定する責務 | なし | Model(2)/同一コンテキスト(2) OK | 並びの規則の所有者が 1 か所になる |

## 影響範囲

- State の並べ替え（`projects#change_order`）と Annotation の並べ替え（`states#update`）の保存結果が変わる。画面の JavaScript とフォームは変更しない
- State の並べ替えは、title と description が両方とも空の State を含むプロジェクトでも成功するようになる。Annotation の並べ替えは、空の Annotation を含んでも成功するようになる。State 自身が検証かスパムキーワード検査に通らない場合は、現状どおり拒否される
- 整数の表記でない position と、同じ id の重複は、成功から 400 に変わる。画面の JavaScript は常に 1 からの整数を 1 枚につき 1 つ送るため、画面からの操作では起きない
- `projects#change_order` が成功するたびにプロジェクトの `updated_at` が更新される。更新日時の降順に並ぶ一覧（トップページ、検索結果、オーナーのページ）で、並べ替えたプロジェクトが上に来る
- position が変わったカードの `updated_at` が更新され、State のフラグメントキャッシュが作り直される。`updated_at` は秒精度のため、同じ秒のうちに同じカードをもう一度並べ替えると、キャッシュが古いまま残ることがある。この制約は現状にもある
- position が同じカードの表示順が id の昇順に固定される。対象はプロジェクト詳細、スライドショー、カード一覧、バックアップである。現在の表示順が id の昇順と違うカードがあると、その表示順が変わる
- State のフラグメントキャッシュのキーは `state.annotations` の SQL のダイジェストを含むため、Annotation の関連に第 2 キーを加えると、デプロイ後に全 State のキャッシュが一度だけ外れる。負荷はキャッシュを全消去したときと同じである
- `projects#change_order` は、`project` キーを含まないリクエスト（State が 0 枚のプロジェクトで並べ替えを確定した場合）も、`states_attributes` が空のリクエストとして成功させる。現状は `ParameterMissing` が `rescue_from Exception` に拾われ、本番で 500 になる
- Annotation の並べ替えフォームには失敗を知らせる処理がないため、Annotation の並べ替えだけが拒否されても画面は成功したように閉じる。画面は変更しない合意のため、既知の制約として残す。State の並べ替えと Annotation の並べ替えは別々のリクエストで同時に送られるが、書き込むカードが重ならないため互いの結果を壊さない
- 次の経路は変更しない。`states#update` と `annotations#update` でカード 1 枚の position を変える経路、カードの作成と削除、State と Annotation の相互変換、プロジェクトのフォーク（State を順序の指定なしに複製する）。position の重複はフォーク先に引き継がれる
- 管理画面の一覧は id の降順で、position に依存しない。Usage と NoteCard は並べ替えを持たない
- テスト: `change_order` の既存スペックは残す。並びを確定する責務のモデルスペックと、両コントローラーのスペックを追加する。表示順の scope を参照する既存スペック（`spec/models/card/state_spec.rb`、`spec/models/card/annotation_spec.rb`、`spec/support/shared_examples/orderable.rb`）は、第 2 キーの追加後も通ることを確かめる

## 関連 ADR

- なし

## 受け入れ条件

| ID | 変更内容の項目 | 種類 | 条件 |
|----|--------------|------|------|
| AC-1 | カードの並びを確定する責務 | 正常 | position が連番のカードを 3〜5 枚持つ範囲で、全順列のどの並びを渡しても、確定後に position、id の昇順で読んだ並びが指定と一致し、position が 1 からの連番になる |
| AC-2 | 同上 | 正常 | position が変わったカードだけ `updated_at` が更新され、position が変わらないカードの `updated_at` は変わらない |
| AC-3 | 同上 | 異常・拒否 | 範囲に属さない id を含む場合は「見つからない」、position が空文字、nil、小数、数字以外の場合と、同じ id を複数回含む場合は「不正なリクエスト」として拒否され、どのカードの position も `updated_at` も変わらない |
| AC-4 | 同上 | 異常・拒否 | 書き込みの途中で例外が起きると、その回の書き込みはすべて取り消される |
| AC-5 | 同上 | 境界 | カードが 1 枚の範囲では、その position が 1 になる。複数のカードに同じ position を指定すると、現在の表示順が先のカードが前になり、position は 1 からの連番になる。負の整数と 0 は並びのキーとして受け付けられる |
| AC-6 | 同上 | 状態・権限 | 確定前の position に重複や欠番がある範囲（`[1,2,3,5,6,6,7]`、`[2,2,3,4,5,6,7]`、`[1,1,2,2,3,3,4,5,6]`、`[1,2,3,5,6,7,8,9,10,11,11]`、`[1,2,3,4,5,6,6,6,8,10,12,12,13,14,15,16,18,18]`）で、1 枚だけ動かす並べ替えと無作為な並べ替えのどちらでも、確定後の並びが指定と一致し、position が 1 からの連番になる |
| AC-7 | 同上 | 状態・権限 | リクエストに含まれないカードは、確定前の表示順で直前にあった「リクエストに含まれるカード」の直後に置かれる。直前にそのようなカードがなければ先頭に置かれる。同じ場所に置かれるカードが複数あれば、確定前の表示順を保つ。title と description が両方とも空のカードを含む範囲でも確定できる |
| AC-8 | State の並べ替え | 正常 | 5 枚の State のうち 1 枚だけを動かすリクエストで `{ success: true }` が返り、保存後の並びが指定と一致する。draft が再生成され、プロジェクトの `updated_at` が、draft の内容が変わらない場合も更新される |
| AC-9 | 同上 | 異常・拒否 | プロジェクトに属さない State の id を含むリクエストは 404 になる。整数の表記でない position を含むリクエストは 400 と `{ success: false }` が返る。どちらも State の position とプロジェクトの `updated_at` は変わらない |
| AC-10 | 同上 | 境界 | `states_attributes` が空のリクエストと、`project` キーを含まないリクエストは成功が返り、State の position は変わらない |
| AC-11 | 同上 | 状態・権限 | プロジェクトを更新できない利用者のリクエストは 400 と `{ success: false }` が返り、position は変わらない。読み取り専用モードでは 503 が返り、position は変わらない |
| AC-12 | Annotation の並べ替え | 正常 | Annotation を 4 枚持つ State で 1 枚だけを動かすリクエストが成功し、保存後の並びが指定と一致する。応答は State の HTML を含む JSON のままである。操作者が State の contributor に加わり、プロジェクトの `updated_at` が更新され、更新通知が送られる |
| AC-13 | 同上 | 異常・拒否 | State に属さない Annotation の id を含むリクエストは 404、整数の表記でない position を含むリクエストは 400 になる。どちらも、Annotation の position、State の属性と `updated_at`、State の contributor は変わらず、更新通知は送られない |
| AC-14 | 同上 | 異常・拒否 | State 自身が検証に通らない場合は 400、State の title か description がスパムキーワードに当たる場合は 422 が現状どおり返り、Annotation の position は変わらない |
| AC-15 | 同上 | 境界 | `annotations_attributes` を含まない `states#update`（カードの編集）では、Annotation の position は変わらない。position の重複や欠番も、そのまま残る |
| AC-16 | 同上 | 状態・権限 | スパムの Annotation を含む State で、画面に出る Annotation だけを送ると、画面に出る Annotation の並びが指定と一致し、スパムを含む全体の position が 1 からの連番になる。スパムの Annotation の位置は AC-7 の規則に従う。スパムの位置の全通り（先頭にある場合を含む）で成り立つ |
| AC-17 | 同上 | 状態・権限 | State を管理できない利用者のリクエストは 401 になり、読み取り専用モードでは 503 が返る。どちらも position は変わらない |
| AC-18 | 表示順の第 2 キー | 正常 | position が同じ State が複数あるとき、プロジェクト詳細、スライドショー、カード一覧、バックアップで id の昇順に並ぶ。position が同じ Annotation も id の昇順に並ぶ |
| AC-19 | 同上 | 異常・拒否 | 該当なし（表示順は入力を受け取らない読み取りの規則である） |
| AC-20 | 同上 | 境界 | すべてのカードの position が同じ（すべて 0）のとき、id の昇順に並ぶ |
| AC-21 | 同上 | 状態・権限 | スパムの Annotation は、第 2 キーを加えた後も公開画面の並びに含まれない |

### 未解決の疑問

- 表示順に第 2 キーを加えると、現在の表示順が変わるカードが本番にあるか。読み取り専用の調査スクリプト（`tmp/change_order_tiebreak_survey.rb`）を本番で実行して確かめる。該当するカードがあれば、件数と内容を見て、第 2 キーを入れるかを決め直す
