# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# マニフェストのファイル名を固定する。既定の名前はビルドごとに変わる乱数を含む。
# Kamal の asset_path は旧バージョンのアセットを新バージョンのボリュームへ上書きなしで
# 写すため、名前が変わると新旧 2 つのマニフェストが並び、Sprockets は名前順で先頭の
# ものを読む。旧マニフェストが選ばれると、コードは新しいのに古い JS・CSS が配信される。
# 名前を固定すれば写しで上書きされず、各バージョンが自身のマニフェストを読む。
Rails.application.config.assets.manifest = Rails.root.join("public/assets/.sprockets-manifest.json").to_s

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
