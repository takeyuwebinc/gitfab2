# ChangeSpec: キーワード検出の強化（入力正規化）

> 要件定義書「スパム運用機能の拡充」2.2 に対応する変更仕様。

## 変更の目的

スパムキーワード検出が、文字分断・全角半角混在・ゼロ幅文字の挿入といった単純な迂回で素通りしている。検出側に入力正規化を加え、既存のキーワード登録を活かしたまま機械的に迂回を吸収する。管理画面のキーワード登録 UI と登録者の運用は変えない。

## 現状

- `SpamKeywordDetector.detect` は、`contents` を半角スペースで連結して `downcase` した文字列に対し、enabled な各 `SpamKeyword` を `combined_content.include?(keyword.keyword.downcase)` で部分一致判定する（[spam_keyword_detector.rb:9-15](app/services/spam_keyword_detector.rb#L9-L15)）。正規化は `downcase` のみ。
- enabled キーワードは `Rails.cache` に1時間キャッシュされ、`SpamKeyword` の AR オブジェクトを保持する（[spam_keyword_detector.rb:43-47](app/services/spam_keyword_detector.rb#L43-L47)）。照合時にキーワード側は毎回 `downcase` されている。
- `detect` の外部呼び出しは `detect_with_logging` のみ。それを呼ぶのは `SpamKeywordDetection` concern の1か所だけ（[spam_keyword_detection.rb:11](app/controllers/concerns/spam_keyword_detection.rb#L11)）。波及範囲は閉じている。
- `detect` は一致した `SpamKeyword`（未正規化の元オブジェクト）を返す。戻り値は検出ログの `detection_reason`（[spam_keyword_detection.rb:19-23](app/controllers/concerns/spam_keyword_detection.rb#L19-L23)）と拒否メッセージの伏字生成（[spam_keyword.rb:9-26](app/models/spam_keyword.rb#L9-L26)）に使われ、いずれも元キーワード文字列に依存する。
- DB の `spam_keywords.keyword` は登録時に前後空白 strip のみ（[spam_keyword.rb:30-32](app/models/spam_keyword.rb#L30-L32)）。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/services/spam_keyword_detector.rb](app/services/spam_keyword_detector.rb) | 検出ロジック本体。**変更対象**（正規化を内部に追加） |
| [app/models/spam_keyword.rb](app/models/spam_keyword.rb) | キーワードモデル。伏字・拒否メッセージ。**変更なし** |
| [app/controllers/concerns/spam_keyword_detection.rb](app/controllers/concerns/spam_keyword_detection.rb) | 検出の呼び出し・ログ記録の起点。**変更なし** |
| [app/services/spam_detection_log_recorder.rb](app/services/spam_detection_log_recorder.rb) | 検出ログの記録器。**変更なし**（呼び出し回数のみ増えうる） |
| [app/models/spam_detection_log.rb](app/models/spam_detection_log.rb) | 検出ログのモデル。**変更なし**（スキーマ不変） |
| [spec/services/spam_keyword_detector_spec.rb](spec/services/spam_keyword_detector_spec.rb) | 検出のテスト。**正規化ケースを追加** |

## 変更内容

`SpamKeywordDetector` の照合ロジックに、照合直前の入力正規化を追加する。実装は同サービス内の private メソッドとして閉じる。

- **追加**: 文字列正規化の private メソッド。以下を順に適用する（要件 2.2.2 / 2.2.4 準拠）。
  1. Unicode NFKC 正規化（`String#unicode_normalize(:nfkc)`、外部 Gem 不要）
  2. ゼロ幅文字の除去（最低限 U+200B / U+200C / U+200D / U+FEFF）。素の NFKC（`unicode_normalize(:nfkc)`）はこれらを除去しない（除去するのは別操作の NFKC_Casefold）ため、独立した手順として明示的に除去する。将来「NFKC があるから不要」と誤って削除されないよう、この理由は実装コメントにも残す。
  3. 空白・区切り記号の除去（半角スペース・タブ・改行・NFKC 後に残る特殊空白、および `_ . - * ' " \` ~ ^ | / \ ( ) [ ] { } < >`）
  4. 小文字化（既存処理を本手順の末尾に統合）
- **変更**: 照合処理を「正規化済み content に、正規化済み keyword が含まれるか」に変更する。検出対象（投稿内容）と登録済キーワードの**両方に同じ正規化を同手順で適用**してから照合する（要件 2.2.3）。
- **追加（要件外・誤検知防止）**: 正規化の結果が空文字列になったキーワードは照合対象から除外する。空文字は `include?` が常に真を返し、全投稿が誤検知される（後述「影響範囲」「受け入れ条件」参照）。
- **不変**: `detect` / `detect_with_logging` の引数・戻り値、DB の `keyword` 本体、キャッシュキーと TTL、管理画面のキーワード登録 UI。`detect` は従来どおり未正規化の `SpamKeyword` オブジェクトを返す。
- **マイグレーションなし**: 既存登録データへの変換は行わない（要件 2.2.3）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 正規化責務の配置 | `SpamKeywordDetector` 内の private メソッド | なし（ADR 起票不要） |

ADR 起票不要と判断した理由: 消費者が `detect` 1経路のみで、`detect` の公開契約を変えず、異コンテキストへの新規結合も生じないため、既存サービスパターンの範囲内に収まる。将来 content 加工を他用途で再利用する必要が生じた時点で別クラスへ抽出すればよく、選び直しコストは低い。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `SpamKeywordDetector` → `SpamKeyword#keyword`（照合での参照） | Model(2)/同コンテキスト(近) OK | Model(2)/同コンテキスト(近) OK | 参照内容のみ変更、結合の強さ・距離は不変 |

新規の結合点は追加しない（正規化は同クラス内 private メソッドに閉じる）。異コンテキストへの結合変化なし。不均衡は増加しない。

## 影響範囲

- **検出ヒット数の増加**: 正規化により従来すり抜けていた投稿が検出されるようになる。誤検知（区切り記号を挟んだ偶発一致）が増える可能性があり、要件 2.2.5 のとおり既存の `enabled=false` 運用で吸収する（追加実装なし）。
- **既存スパム検出ログの件数増加**: 検出が増えると、`SpamKeywordDetection` concern → `SpamDetectionLogRecorder.record` 経由で記録される `SpamDetectionLog`（`detection_method: "keyword"`）の件数が増えうる。**ログのスキーマ・項目・出力先・保存期間は変更しない**（`detection_reason` は従来どおり元キーワード文字列）。
- **アプリログ出力量の増加**: 検出時に `SpamKeywordDetector` が出す `Rails.logger.info` の出力件数も増えうる（出力フォーマットは不変）。既存 spec はこのログ文字列に依存するため、フォーマットを変えないこと。
- **テスト**:
  - 既存テストは正規化の上位互換のため維持される見込み（downcase・複数コンテンツ・空・無効化キーワード）。
  - 追加が必要: 全角→半角一致、文字分断（記号・空白挿入）、ゼロ幅文字挿入、キーワード側にも正規化が適用されること、正規化後に空文字化するキーワードで全件誤検知が起きないこと。
- **パフォーマンス**: 既存も照合のたびにキーワードを `downcase` しており、毎回の正規化は既存挙動と同等オーダー。キーワード件数は小規模で TTL 1時間のキャッシュも変えないため、追加の最適化（正規化済みキーワードのキャッシュ）は本変更では行わない。

## 関連 ADR

- なし

## 受け入れ条件

- [ ] 全角英数字で登録したキーワードが、半角英数字で投稿された文字列にマッチする
- [ ] `バイアグラ` を登録した場合、`バ_イ_ア_グ_ラ` / `バ.イ.ア.グ.ラ` / `バ イ ア グ ラ` などの分断投稿が検出される
- [ ] ゼロ幅文字（U+200B / U+200C / U+200D / U+FEFF）を挿入した投稿が検出される
- [ ] キーワード照合時、キーワード自体にも投稿内容と同じ正規化が適用される
- [ ] 正規化後に空文字列となるキーワード（区切り記号のみ等）が照合対象から除外され、無関係な投稿が誤検知されない
- [ ] `detect` は未正規化の元 `SpamKeyword` を返し、検出ログの `detection_reason` と拒否メッセージの伏字が従来と変わらない
- [ ] 既存の検出挙動（大文字小文字非区別・複数コンテンツ・空コンテンツ・無効化キーワード）が維持される
- [ ] `enabled=false` のキーワードは、正規化適用後も照合対象に含まれない（要件 2.2.5 の誤検知吸収運用が機能する）
- [ ] 管理画面のキーワード登録 UI に変更がない
- [ ] DB の `spam_keywords.keyword` 本体は正規化されず、マイグレーションも発生しない
