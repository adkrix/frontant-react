# Webpack Configuration
# https://github.com/webpack/webpack
# http://webpack.github.io/docs/configuration.html

_ = require('lodash')
fs = require('fs')
path = require('path')
webpack = require('webpack')

module.exports = {}

entries = module.exports.entry =
  "main": "./src/scripts/main.coffee"
  "styles": "./src/styles/styles.scss"
  "vendor/es5-shim": "./bower_components/es5-shim/es5-shim.js"
  "vendor/es5-sham": "./bower_components/es5-shim/es5-sham.js"

outputDir = path.join(__dirname, "dist", "assets")

jsLoaders = ["jsx"]
scriptModLoaders = [
  test: /\.coffee$/
  loaders: jsLoaders.concat(["coffee"])
,
  test: /\.litcoffee$/
  loaders: jsLoaders.concat(["coffee?literate"])
,
  test: /\.js$/
  loaders: jsLoaders
]

cssLoaders = ['style', 'css', 'autoprefixer-loader?last 2 versions']
bowerPath = path.resolve(__dirname, './bower_components')
styleModLoaders = [
  test: /\.scss$/,
  loaders: cssLoaders.concat(["sass?precision=10&outputStyle=expanded&sourceMap=true&includePaths[]=#{bowerPath}"])
,
  test: /\.css$/
  loaders: cssLoaders
]

staticModLoaders = [
  test: /\.gif$/
  loader: "url?limit=10000&mimetype=image/gif"
,
  test: /\.jpg$/
  loader: "url?limit=10000&mimetype=image/jpg"
,
  test: /\.png$/
  loader: "url?limit=10000&mimetype=image/png"
,
  test: /\.woff2$/
  loader: "url?limit=10000&mimetype=application/font-woff2"
,
  test: /\.woff$/
  loader: "url?limit=10000&mimetype=application/font-woff"
,
  test: /\.ttf$/
  loader: "file?mimetype=application/vnd.ms-fontobject"
,
  test: /\.eot$/
  loader: "file?mimetype=application/x-font-ttf"
,
  test: /\.svg$/
  loader: "file?mimetype=image/svg+xml"
]

ExtractTextPlugin = require("extract-text-webpack-plugin")

styleModLoaders = styleModLoaders.map (e) ->
  test: e.test
  loader: ExtractTextPlugin.extract(e.loaders.slice(1).join('!'))

extractTextPlugin = new ExtractTextPlugin("[name].css", allChunks: true)

definePlugin = new webpack.DefinePlugin(
  __PRODUCTION__: JSON.stringify(false)
)

generateManifestPlugin = (compiler) ->
  @plugin 'done', (stats) ->
    stats = stats.toJson()

    assetStats = stats.assetsByChunkName
    setCssExt = (p) -> p.replace(/\.js$/, '.css')
    for entryName, entryPath of assetStats when /\.(?:scss|sass|css)$/.test(entries[entryName])
      if _.isArray(entryPath)
        assetStats[entryName] = entryPath.map (p) -> setCssExt(p)
      else
        assetStats[entryName] = setCssExt(entryPath)

    fs.writeFileSync(path.join(outputDir, "asset-stats.json"), JSON.stringify(stats.assetsByChunkName, null, 2))

_.merge module.exports,
  target: "web"
  cache: true
  debug: true
  watch: false
  devtool: 'source-map'
  output:
    path: outputDir
    publicPath: "/assets/"
    filename: "[name].js"
    chunkFilename: "[name].[id].[chunkhash].js"
  resolve:
    modulesDirectories: [
      'src'
      'bower_components'
      'node_modules'
    ]
  module:
    loaders: styleModLoaders.concat(scriptModLoaders).concat(staticModLoaders)

  plugins: [
    definePlugin
    extractTextPlugin
    generateManifestPlugin
  ]

  mergeProductionConfig: (addHashes = true) ->

    definePlugin.definitions.__PRODUCTION__ = JSON.stringify(true)
    _.merge @,
      output:
        filename: "[name]-[hash].js"
    extractTextPlugin.filename = '[name]-[hash].css'

    _.merge @,
      debug: false
      watch: false
      devtool: null
      plugins: @plugins.concat [
        new webpack.optimize.OccurenceOrderPlugin(preferEntry: true)
        new webpack.optimize.UglifyJsPlugin()
      ]
