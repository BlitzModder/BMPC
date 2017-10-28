gulp = require "gulp"
notify = require "gulp-notify"
plumber = require "gulp-plumber"
changed = require "gulp-changed"
coffee = require "gulp-coffeescript"
sass = require "gulp-sass"
haml = require "gulp-haml"
yaml = require "gulp-yaml"
del = require "del"

path =
  coffeeSrc: "src/**/*.coffee"
  coffeeBin: "bin"
  hamlSrc: "src/gui/**/*.haml"
  hamlBin: "bin/gui"
  scssSrc: "src/gui/css/**/*.scss"
  scssBin: "bin/gui/css"
  imgSrc: "src/gui/img/**"
  imgBin: "bin/gui/img"
  yamlSrc: "src/lang/**"
  yamlBin: "bin/lang"
  packageJsonSrc: "src/package.json"
  packageJsonBin: "bin"

gulp.task "default", ["coffee", "haml", "scss", "img", "yaml", "package.json"]

gulp.task "coffee", ->
  return gulp.src(path.coffeeSrc)
    .pipe(plumber(errorHandler: notify.onError("Error: <%= error.toString() %>")))
    .pipe(changed(path.coffeeBin))
    .pipe(coffee(bare: true))
    .pipe(gulp.dest(path.coffeeBin))

gulp.task "haml", ->
  return gulp.src(path.hamlSrc)
    .pipe(plumber({errorHandler: notify.onError("Error: <%= error.toString() %>")}))
    .pipe(changed(path.hamlBin))
    .pipe(haml())
    .pipe(gulp.dest(path.hamlBin))

gulp.task "scss", ->
  return gulp.src(path.scssSrc)
    .pipe(plumber({errorHandler: notify.onError("Error: <%= error.toString() %>")}))
    .pipe(changed(path.scssBin))
    .pipe(sass())
    .pipe(gulp.dest(path.scssBin))

gulp.task "img", ->
  return gulp.src(path.imgSrc)
    .pipe(plumber({errorHandler: notify.onError("Error: <%= error.toString() %>")}))
    .pipe(changed(path.imgBin))
    .pipe(gulp.dest(path.imgBin))

gulp.task "yaml", ->
  return gulp.src(path.yamlSrc)
    .pipe(plumber({errorHandler: notify.onError("Error: <%= error.toString() %>")}))
    .pipe(changed(path.yamlBin))
    .pipe(yaml())
    .pipe(gulp.dest(path.yamlBin))

gulp.task "package.json", ->
  return gulp.src(path.packageJsonSrc)
    .pipe(plumber({errorHandler: notify.onError("Error: <%= error.toString() %>")}))
    .pipe(changed(path.packageJsonBin))
    .pipe(gulp.dest(path.packageJsonBin))

gulp.task "clean", (cb) ->
  return del ["./bin"], cb

