# reCAPTCHA v3 セットアップガイド

## 概要

新規プロジェクト投稿時のボット対策として、Google reCAPTCHA v3を導入するための手順書。

## 必要なAPIキー

| キー | 用途 | 公開可否 |
|------|------|----------|
| サイトキー (Site Key) | フロントエンド（JavaScript）で使用 | 公開可 |
| シークレットキー (Secret Key) | サーバーサイドでトークン検証に使用 | **秘密** |

## APIキー取得手順

### 1. Google reCAPTCHA管理コンソールにアクセス

https://www.google.com/recaptcha/admin

### 2. 新規サイトを登録

「+」ボタンをクリックして新規サイトを作成。

### 3. 設定項目を入力

| 項目 | 設定値 |
|------|--------|
| ラベル | 識別しやすい名前（例: `fabble.cc`） |
| reCAPTCHA タイプ | **reCAPTCHA v3** を選択 |
| ドメイン | 使用する全ドメインを登録（下記参照） |

#### 登録するドメイン

```
fabble.cc
localhost
```

### 4. 利用規約に同意して送信

### 5. APIキーを取得

発行された以下のキーを控える：
- **サイトキー**
- **シークレットキー**

## キーの設定方法

環境変数とRails Credentialsの両方に対応。環境変数があれば優先される。

### 環境変数

```bash
RECAPTCHA_SITE_KEY=...
RECAPTCHA_SECRET_KEY=...
```

### Rails Credentials

```bash
bin/rails credentials:edit --environment development
```

```yaml
recaptcha:
  site_key: your_site_key_here
  secret_key: your_secret_key_here
```

## Gemの追加

```ruby
# Gemfile
gem 'recaptcha'
```

```bash
bundle install
```

## 注意事項

- 本番環境では必ずGoogle管理コンソールから取得した専用キーを使用する
- キーが設定されていない場合、reCAPTCHA検証はスキップされる

## 料金

| プラン | リクエスト数 | 料金 |
|--------|-------------|------|
| 無料枠 | 月間100万リクエストまで | 無料 |
| 有料枠 | 100万リクエスト超過分 | $1/1000リクエスト |

通常の利用であれば無料枠で十分。

## 参考リンク

- [Google reCAPTCHA 管理コンソール](https://www.google.com/recaptcha/admin)
- [reCAPTCHA v3 公式ドキュメント](https://developers.google.com/recaptcha/docs/v3)
- [recaptcha gem (GitHub)](https://github.com/ambethia/recaptcha)

---

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|------------|------|----------|
| 1.0 | 2026/01/06 | 初版作成 |
