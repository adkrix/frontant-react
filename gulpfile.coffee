g = require('gulp')
gutil = require('gulp-util')
clean = require('gulp-clean')
watch = require('gulp-watch')
gzip = require('gulp-gzip')
notify = require('gulp-notify')
runSequence = require('run-sequence')
deployToGithubPages = require('gulp-gh-pages')
_ = require('lodash')

webpack = require('webpack')

express = require('express')
tiny_lr = require('tiny-lr')

util = require('util')
tty = require('tty')
path = require('path')
through2 = require('through2')


requireUncached = (path) ->
  delete require.cache[require.resolve(path)]
  require(path)

paths = {}

paths.src = 'src'
paths.srcFiles = "#{paths.src}/**/*"

paths.dist = 'dist'
paths.distFiles = "#{paths.dist}/**/*"

paths.webpackPaths = [
  'src/scripts', 'src/scripts/**/*',
  'src/styles', 'src/styles/**/*',
  'src/images', 'src/images/**/*'
]

paths.replaceAssetRefs = [
  "#{paths.src}/index.html"
]

paths.webpackConfig = './webpack.config.litcoffee'
loadWebpackConfig = -> requireUncached(paths.webpackConfig)
webpackConfig = loadWebpackConfig()

g.task 'default', ->
  help = """
    Usage: bin/gulp [command]

    Available commands:
      bin/gulp                 # display this help message
      bin/gulp dev             # build and run dev server
      bin/gulp prod            # production build, hash and gzip
      bin/gulp clean           # rm /dist
      bin/gulp build           # development build
      bin/gulp deploy-gh-pages # deploy to Github Pages
  """
  setTimeout (-> console.log help), 200

g.task 'dev', ['build'], ->
  servers = createServers(4000, 35729)
  logChange = (evt) -> gutil.log(gutil.colors.cyan(evt.path), 'changed')
  # Run webpack on config changes
  g.watch [paths.webpackConfig], (evt) ->
    logChange evt
    webpackConfig = loadWebpackConfig()
    g.start 'webpack'
  # Run build on app source changes
  g.watch [paths.srcFiles], (evt) ->
    logChange evt
    g.start 'build'
  # Notify browser on distribution changes
  g.watch [paths.distFiles], (evt) ->
    logChange evt
    servers.liveReload.changed body: {files: [evt.path]}



g.task 'prod', (cb) ->
  # Apply production config, pass true to append hashes to file names
  setWebpackConfig loadWebpackConfig().mergeProductionConfig()
  runSequence 'clean', 'build', 'gzip', cb

g.task 'clean', ->
  g.src(paths.dist, read: false).pipe(clean())


g.task 'build', (cb) ->
  runSequence 'webpack', 'build-replace-asset-refs', 'copy', cb

g.task 'webpack', (cb) ->
  gutil.log("[webpack]", 'Compiling...')
  webpack webpackConfig, (err, stats) ->
    if (err) then throw new gutil.PluginError("webpack", err)
    gutil.log("[webpack]", stats.toString(colors: tty.isatty(process.stdout.fd)))
    cb()

g.task 'copy', ->
  g.src([paths.srcFiles].concat(paths.webpackPaths.concat(paths.replaceAssetRefs).map (path) -> "!#{path}")).pipe(g.dest paths.dist)

g.task 'gzip', ->
  g.src(paths.distFiles)
  .on('error', handleErrors)
  .pipe(gzip())
  .pipe(g.dest paths.dist)


g.task 'build-replace-asset-refs', ->
  g.src(paths.replaceAssetRefs).pipe(
    replaceWebpackAssetUrlsInFiles(
      requireUncached("./#{paths.dist}/assets/asset-stats.json"),
      webpackConfig.output.publicPath
    )).pipe(g.dest paths.dist)


g.task 'build-gh-pages', (cb) ->
  webpackConfig = _.merge loadWebpackConfig().mergeProductionConfig(),
    output:
     publicPath: "/gulp-webpack-react-bootstrap-sass-template/assets/"
  runSequence 'clean', 'build', cb

g.task 'deploy-gh-pages', ['build-gh-pages'], ->
  g.src(paths.distFiles).pipe(deployToGithubPages(cacheDir: './tmp/.gh-pages-cache'))

setWebpackConfig = (conf) ->
  webpackConfig = conf

createServers = (port, lrport) ->
  liveReload = tiny_lr()
  liveReload.listen lrport, ->
    gutil.log 'LiveReload listening on', lrport
  app = express()
  app.use express.static(path.resolve paths.dist)
  app.listen port, ->
    gutil.log 'HTTP server listening on', port
  {liveReload, app}


replaceWebpackAssetUrlsInFiles = (stats, publicPath) ->

  through2.obj (vinylFile, enc, cb) ->
    vinylFile.contents = new Buffer(replaceWebpackAssetUrls(String(vinylFile.contents), stats, publicPath))
    @push vinylFile
    cb()

replaceWebpackAssetUrls = (text, stats, publicPath) ->

  for entryName, targetPath of stats

    if util.isArray(targetPath)
      targetPath = _.find targetPath, (p) -> path.extname(p).toLowerCase() != '.map'

    ref = "assets/#{entryName}#{path.extname(targetPath)}"
    text = text.replace ref, publicPath + targetPath

  text


handleErrors = (args...) ->
  notify.onError(title: 'Error', message: '<%= error.message %>').apply(@, args)
  @emit 'end'
