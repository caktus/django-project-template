var gulp = require("gulp")
var source = require('vinyl-source-stream') // Used to stream bundle for further handling
var browserify = require('browserify')
var watchify = require('watchify')
var babelify = require('babelify')
var gulpif = require('gulp-if')
var uglify = require('gulp-uglify')
var streamify = require('gulp-streamify')
var notify = require('gulp-notify')
var gutil = require('gulp-util')
var rename = require('gulp-rename')
var stylus = require('gulp-stylus')
var stylint = require('gulp-stylint')
var livereload = require('gulp-livereload')
var postcss = require('gulp-postcss')
var autoprefixer = require('autoprefixer')
var objectfitimages = require('postcss-object-fit-images')
var mocha = require('gulp-mocha')
var istanbul = require('gulp-istanbul')
var isparta = require('isparta')
var sourcemaps = require('gulp-sourcemaps');

var spawn = require('child_process').spawn
var argv = require('yargs')
  .default('port', 8000)
  .default('address', 'localhost')
  .argv

// External dependencies you do not want to rebundle while developing,
// but include in your application deployment
var dependencies = [
]

var options = {
  src: './{{ project_name }}/static/js/index.js',
  dest: './{{ project_name }}/static/js/dist/',

  css: {
    src: './{{ project_name }}/static/stylus/index.styl',
    watch: './{{ project_name }}/static/stylus/**/*',
    dest: './{{ project_name }}/static/css/dist'
  },
  development: false
}

if (argv._ && argv._[0] === 'deploy') {
  options.development = false
} else {
  options.development = true
}

if (options.development) {
  console.log('Building for development')
  delete process.env['NODE_ENV']
  // Be more verbose for developers
  gulp.onAll(function (e) {
    console.log(e)
  })
} else {
  console.log("Building for production")
  process.env['NODE_ENV'] = 'production';
}

function handleBundleErrors(err) {
  gutil.log(err)
  if (options.development === false) {
    process.exit(1)
  }
}

var browserifyTask = function () {
  // Our app bundler
  var appBundler = browserify({
    entries: [options.src], // Only need initial file, browserify finds the rest
    transform: [babelify], // We want to convert JSX to normal javascript
    debug: options.development, // Gives us sourcemapping
    cache: {},
    packageCache: {},
    fullPaths: options.development // Requirement of watchify
  });

  // We set our dependencies as externals on our app bundler when developing
  (options.development ? dependencies : []).forEach(function (dep) {
    appBundler.external(dep)
  })

  // The rebundle process
  var rebundle = function () {
    var start = Date.now()
    console.log('Building APP bundle')
    appBundler.bundle()
      .on('error', handleBundleErrors)
      .pipe(source('index.js'))
      .pipe(gulpif(!options.development, streamify(uglify())))
      .pipe(rename('bundle.js'))
      .pipe(gulp.dest(options.dest))
      .pipe(gulpif(options.development, livereload()))
      .pipe(notify(function () {
        console.log('APP bundle built in ' + (Date.now() - start) + 'ms')
      }))
  }

  // Fire up Watchify when developing
  if (options.development) {
    appBundler = watchify(appBundler)
    appBundler.on('update', rebundle)
  }

  // We create a separate bundle for our dependencies as they
  // should not rebundle on file changes. This only happens when
  // we develop. When deploying the dependencies will be included
  // in the application bundle
  if (options.development) {
    var vendorsBundler = browserify({
      debug: true,
      require: dependencies
    })

    // Run the vendor bundle
    var start = new Date()
    console.log('Building VENDORS bundle')
    vendorsBundler.bundle()
      .on('error', handleBundleErrors)
      .pipe(source('vendors.js'))
      .pipe(gulpif(!options.development, streamify(uglify())))
      .pipe(gulp.dest(options.dest))
      .pipe(notify(function () {
        console.log('VENDORS bundle built in ' + (Date.now() - start) + 'ms')
      }))
  }

  return rebundle()
}
gulp.task('browserify', browserifyTask)

gulp.task('stylint', function () {
  var lintOpts = {
    failOnWarning: true
  }

  return gulp.src(options.css.watch)
    .pipe(stylint()) // our linting rules can be found in the .stylintrc file
    .pipe(stylint.reporter())
    .pipe(stylint.reporter('fail', lintOpts))
})

var cssTask = function () {
  var stylusOpts = {
    compress: true
  }
  var prefixerOpts = {
    browsers: ['last 2 versions'],
    cascade: false,
    grid: true // We are living in the future, folks!
  }
  if (options.development) {
    var run = function () {
      var start = Date.now()
      console.log('Building CSS bundle')
      return gulp.src(options.css.src)
          .pipe(sourcemaps.init())
          .pipe(stylus(stylusOpts).on('error', function (e) {
            console.log('stylus error', e)
          }))
          .pipe(postcss([ autoprefixer(prefixerOpts), objectfitimages() ]))
          .pipe(sourcemaps.write())
          .pipe(rename('bundle.css'))
          .pipe(gulp.dest(options.css.dest))
          .pipe(livereload())
          .pipe(notify(function () {
            console.log('CSS bundle built in ' + (Date.now() - start) + 'ms')
          }))
    }
    gulp.watch(options.css.watch, run)
    return run()
  } else {
    return gulp.src(options.css.src)
        .pipe(stylus(stylusOpts).on('error', function (e) {
          console.log('stylus error', e)
        }))
        .pipe(postcss([ autoprefixer(prefixerOpts), objectfitimages() ]))
        .pipe(rename('bundle.css'))
        .pipe(gulp.dest(options.css.dest))
  }
}
gulp.task('css', cssTask)

gulp.task('rebuild', ['css', 'browserify'])

// Starts our development workflow
function startDevServer (done) {
  console.log('Starting Django runserver http://' + argv.address + ':' + argv.port + '/')
  var args = ['manage.py', 'runserver', argv.address + ':' + argv.port]
  var runserver = spawn('python', args, {
    stdio: 'inherit'
  })
  runserver.on('close', function (code) {
    if (code !== 0) {
      console.error('Django runserver exited with error code: ' + code)
    } else {
      console.log('Django runserver exited normally.')
    }
  })
  done()
}

gulp.task('startDevServer', ['rebuild'], startDevServer)

// Starts our development workflow
gulp.task('default', ['startDevServer'], function (done) {
  livereload.listen()
  done()
})

gulp.task('deploy', ['rebuild'])

gulp.task('pre-test',  function () {
  return gulp
    .src('./{{ project_name }}/static/js/app/**/*.js')
    .pipe(istanbul({
      instrumenter: isparta.Instrumenter,
      includeUntested: true
    }))
    .pipe(istanbul.hookRequire())
})

gulp.task('test', ['pre-test'], function () {
  return gulp
    .src('./{{ project_name }}/static/js/test/**/test_*.js', {read: false})
    .pipe(mocha({
      require: [
        'jsdom-global/register',
        'babel-core/register'
      ]
    }))
    .pipe(istanbul.writeReports({
      dir: './coverage/',
      reportOpts: {
        dir: './coverage/'
      },
      reporters: [
        'text',
        'text-summary',
        'json',
        'html'
      ]
    }))
    // .pipe(istanbul.enforceThresholds({
    //   thresholds: {
    //     global: {
    //       statements: 80, // goal: 90
    //       branches: 90,
    //       functions: 70,
    //       lines: 0 // TODO: find out why this is basically not working at all
    //     }
    //   }
    // }))
})
