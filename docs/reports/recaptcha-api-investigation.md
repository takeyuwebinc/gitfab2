# reCAPTCHA v3 導入に必要なAPIキー調査報告書

**作成日**: 2026/01/06
**ステータス**: Final

## 概要

### 調査の背景

スパムプロジェクト投稿抑制機能（要件定義書: [spam-prevention.md](../requirements/spam-prevention.md)）の実装にあたり、新規プロジェクト投稿時のreCAPTCHA v3機能が要件として定義されている。この機能を実装するために必要なAPIキーおよび関連情報の調査が必要となった。

### 調査の目的

1. reCAPTCHA v3の導入に必要なAPIキーを特定する
2. 現在のプロジェクトにおけるreCAPTCHA関連の設定状況を確認する
3. APIキーの取得方法と設定方法を明らかにする

### 調査範囲

**調査対象**:
- Google reCAPTCHA v3の仕様
- 現プロジェクトの環境変数設定
- 現プロジェクトのGemfile（既存のreCAPTCHA関連gem）

**調査対象外**:
- 実装方法の詳細設計
- 他のCAPTCHAサービスとの比較

## 調査内容

### 調査対象

| 対象 | 説明 |
|------|------|
| `.env.sample` | 環境変数のサンプルファイル |
| `Gemfile` | プロジェクトの依存gem定義 |
| Google reCAPTCHA公式ドキュメント | APIキーの仕様と取得方法 |

### 調査方法

1. プロジェクト内のreCAPTCHA関連設定の検索（Grep）
2. 環境変数ファイルの確認
3. Gemfileの確認
4. Google reCAPTCHA公式ドキュメントの参照

## 調査結果

### 現プロジェクトの状況

| 項目 | 結果 |
|------|------|
| reCAPTCHA関連gem | **未導入** |
| reCAPTCHA関連の環境変数 | **未設定** |
| reCAPTCHA関連のコード | **なし** |

現時点でreCAPTCHA関連の設定は一切存在しない。新規導入が必要。

### 必要なAPIキー

reCAPTCHA v3の導入には以下の2つのキーが必要：

| キー名 | 用途 | 保管方法 |
|--------|------|----------|
| サイトキー (Site Key) | フロントエンド（JavaScript）でreCAPTCHAウィジェットを初期化する際に使用 | 環境変数 or Rails Credentials |
| シークレットキー (Secret Key) | サーバーサイドでGoogleのAPIを呼び出してトークンを検証する際に使用 | 環境変数 or Rails Credentials（**秘密情報**） |

### APIキーの取得元

Google reCAPTCHA管理コンソール: https://www.google.com/recaptcha/admin

### 推奨gem

| gem名 | GitHub | 説明 |
|-------|--------|------|
| `recaptcha` | https://github.com/ambethia/recaptcha | Rails向けreCAPTCHAヘルパー。v2/v3両対応 |

### 料金体系

| プラン | リクエスト数 | 料金 |
|--------|-------------|------|
| 無料枠 | 月間100万リクエストまで | 無料 |
| 有料枠 | 100万リクエスト超過分 | $1/1000リクエスト |

## 分析・考察

### 主要な発見

1. **新規導入が必要**: 現プロジェクトにはreCAPTCHA関連の設定が一切存在しないため、完全な新規導入となる
2. **外部サービス依存**: Google reCAPTCHA APIへの依存が発生する。要件定義書ではAPI障害時のフォールバック（検証スキップ）が定義済み
3. **無料枠で運用可能**: 月間100万リクエストまで無料のため、通常の利用では追加コストは発生しない

### リスクと制約

| リスク/制約 | 説明 | 対策 |
|-------------|------|------|
| 外部サービス障害 | Google reCAPTCHA APIの障害時に検証不可 | 要件定義書にてフォールバック動作を定義済み（検証スキップして投稿許可） |
| ドメイン登録必須 | 使用するドメインをGoogle管理コンソールに事前登録が必要 | `fabble.cc` と `localhost` を登録 |
| 環境別キー管理 | 本番・開発で異なるキーを使用する場合、管理が複雑化 | 環境ごとにcredentialsでキーを管理 |

## 結論・推奨事項

### 結論

reCAPTCHA v3の導入には**サイトキー**と**シークレットキー**の2つのAPIキーが必要であり、Google reCAPTCHA管理コンソールから取得できる。現プロジェクトにはreCAPTCHA関連の設定が存在しないため、新規にgemの追加と環境変数の設定が必要となる。

### 推奨事項

1. **`recaptcha` gemの導入**
   - 理由: Rails向けの成熟したライブラリであり、reCAPTCHA v3に対応している
   - 期待効果: ビューヘルパーやコントローラーヘルパーにより実装工数を削減できる

2. **環境変数優先のフォールバック方式**
   - 理由: 環境変数があれば優先、なければRails Credentialsから取得する方式により、オープンソースとしての利用しやすさを維持
   - 期待効果: 外部利用者は環境変数のみで設定可能、本プロジェクトはcredentialsで管理可能

3. **キー未設定時は検証スキップ**
   - 理由: 開発環境でキーを設定しなくても動作するため、初期セットアップの手間を軽減できる
   - 期待効果: 開発環境でのreCAPTCHA検証によるブロックを回避できる

### 次のアクション

- [ ] Google reCAPTCHA管理コンソールで本番環境用のAPIキーを取得（ドメイン: `fabble.cc`, `localhost`）
- [ ] Gemfileに`gem 'recaptcha'`を追加
- [ ] 本番環境のcredentialsに取得したキーを設定

## 参考資料

- [Google reCAPTCHA 管理コンソール](https://www.google.com/recaptcha/admin)
- [reCAPTCHA v3 公式ドキュメント](https://developers.google.com/recaptcha/docs/v3)
- [recaptcha gem (GitHub)](https://github.com/ambethia/recaptcha)
- [スパムプロジェクト投稿抑制機能 要件定義書](../requirements/spam-prevention.md)
- [reCAPTCHA v3 セットアップガイド](../guides/recaptcha-setup.md)

## 付録

### Gemfileの追加例

```ruby
# Gemfile
gem 'recaptcha'
```

### 環境変数

```bash
RECAPTCHA_SITE_KEY=...
RECAPTCHA_SECRET_KEY=...
```

### Rails Credentials

```yaml
recaptcha:
  site_key: ...
  secret_key: ...
```

### アプリケーションでの参照方法

```ruby
# 環境変数優先、なければCredentialsから取得
ENV['RECAPTCHA_SITE_KEY'] || Rails.application.credentials.dig(:recaptcha, :site_key)
ENV['RECAPTCHA_SECRET_KEY'] || Rails.application.credentials.dig(:recaptcha, :secret_key)
```

※キーが設定されていない場合、reCAPTCHA検証はスキップされる
