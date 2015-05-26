gulp       = require 'gulp'
coffee     = require 'gulp-coffee'
gutil      = require 'gulp-util'
browserify = require 'gulp-browserify'
uglify     = require 'gulp-uglify'

paths =
  coffee: './src/**/*.coffee'

out = 'lib'

# compile coffeescript
gulp.task 'coffee', ->
  gulp.src paths.coffee
    .pipe coffee().on 'error', gutil.log
    .pipe gulp.dest './lib/'


# make it a single standalone file
gulp.task 'package', ->
  gulp.src './lib/index.js'
    .pipe browserify
      standalone: 'subplay'
    .pipe uglify()
    .pipe gulp.dest './'


gulp.task 'default', ['coffee', 'package']
