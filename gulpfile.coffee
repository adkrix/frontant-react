gulp = require('gulp')
gutil = require('gulp-util')
clean = require('gulp-clean')
watch = require('gulp-watch')
gzip = require('gulp-gzip')
notify = require('gulp-notify')
deployToGithubPages = require('gulp-gh-pages')

runSequence = require('run-sequence')

_ = require('lodash')
webpack = require('webpack')
express = require('express')
tiny_lr = require('tiny-lr')
open = require("open")
util = require('util')
tty = require('tty')
path = require('path')
through2 = require('through2')

paths =
  src: 'src'
  dist: 'dist'
  webpackPaths: [
    'src/scripts', 'src/scripts/**/*',
    'src/styles', 'src/styles/**/*',
    'src/images', 'src/images/**/*'
  ]
  webpackConfig: './webpack.config.coffee'

paths.srcFiles = "#{paths.src}/**/*"
paths.distFiles = "#{paths.dist}/**/*"
paths.replaceAssetRefs = [
  "#{paths.src}/index.html"
]

requireUncached = (path) ->
  delete require.cache[require.resolve(path)]
  require(path)

loadWebpackConfig = -> requireUncached(paths.webpackConfig)
webpackConfig = loadWebpackConfig()

setWebpackConfig = (conf) ->
  webpackConfig = conf

createServers = (port, lrport) ->
  liveReload = tiny_lr()
  liveReload.listen lrport, ->
    gutil.log 'LiveReload listening on', lrport
  app = express()
  app.use express.static(path.resolve paths.dist)
  app.listen port, (e) ->
    gutil.log 'HTTP server listening on', port
    open("http://localhost:#{port}")
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

###############
# tasks
###############
gulp.task 'clean', ->
  gulp.src(paths.dist, read: false).pipe(clean())

gulp.task 'build', (cb) ->
  runSequence 'webpack', 'build-replace-asset-refs', 'copy', cb

gulp.task 'webpack', (cb) ->
  gutil.log("[webpack]", 'Compiling...')
  webpack webpackConfig, (err, stats) ->
    if (err) then throw new gutil.PluginError("webpack", err)
    gutil.log("[webpack]", stats.toString(colors: tty.isatty(process.stdout.fd)))
    cb()

gulp.task 'copy', ->
  gulp.src([paths.srcFiles].concat(
      paths.webpackPaths.concat(paths.replaceAssetRefs).map (path) -> "!#{path}")
  ).pipe(gulp.dest paths.dist)

gulp.task 'gzip', ->
  gulp.src(paths.distFiles)
    .on('error', handleErrors)
    .pipe(gzip())
    .pipe(gulp.dest paths.dist)

gulp.task 'build-replace-asset-refs', ->
  gulp.src(paths.replaceAssetRefs).pipe(
    replaceWebpackAssetUrlsInFiles(
      requireUncached("./#{paths.dist}/assets/asset-stats.json"),
      webpackConfig.output.publicPath
    )).pipe(gulp.dest paths.dist)

gulp.task 'build-gh-pages', (cb) ->
  webpackConfig = _.merge loadWebpackConfig().mergeProductionConfig(),
    output:
      publicPath: "/gulp-webpack-react-bootstrap-sass-template/assets/"
  runSequence 'clean', 'build', cb

###############
# main tasks
###############
gulp.task 'default', ->
  help = """
    Usage: gulp [command]

    Available commands:
      gulp                 # display this help message
      gulp dev             # build and run dev server
      gulp prod            # production build, hash and gzip
      gulp deploy-gh-pages # deploy to Github Pages
  """
  setTimeout (-> console.log help), 200

gulp.task 'dev', ['build'], ->
  servers = createServers(4000, 35729)
  logChange = (evt) -> gutil.log(gutil.colors.cyan(evt.path), 'changed')
  # Run webpack on config changes
  gulp.watch [paths.webpackConfig], (evt) ->
    logChange evt
    webpackConfig = loadWebpackConfig()
    gulp.start 'webpack'
  # Run build on app source changes
  gulp.watch [paths.srcFiles], (evt) ->
    logChange evt
    gulp.start 'build'
  # Notify browser on distribution changes
  gulp.watch [paths.distFiles], (evt) ->
    logChange evt
    servers.liveReload.changed body: {files: [evt.path]}

gulp.task 'prod', (cb) ->
  # Apply production config, pass true to append hashes to file names
  setWebpackConfig loadWebpackConfig().mergeProductionConfig()
  runSequence 'clean', 'build', 'gzip', cb

gulp.task 'deploy-gh-pages', ['build-gh-pages'], ->
  gulp.src(paths.distFiles).pipe(deployToGithubPages(cacheDir: './tmp/.gh-pages-cache'))

