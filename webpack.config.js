const path    = require("path")
const webpack = require("webpack")

module.exports = {
  mode: "production",
  devtool: "source-map",
  entry: {
    like: "./app/frontend/like.ts"
  },
  output: {
    filename: "[name].js",
    sourceMapFilename: "[file].map",
    chunkFormat: "module",
    path: path.resolve(__dirname, "app/assets/builds"),
  },
  resolve: {
    extensions: [".ts", ".tsx", ".js"]
  },

  module: {
    rules: [{ test: /\.tsx?$/, loader: "ts-loader" }]
  },
  plugins: [
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    })
  ]
}
