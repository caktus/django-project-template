var gulp = require('gulp');
var source = require('vinyl-source-stream'); // Used to stream bundle for further handling
var browserify = require('browserify');
var watchify = require('watchify');
var babelify = require('babelify');
var gulpif = require('gulp-if');
var uglify = require('gulp-uglify');
var streamify = require('gulp-streamify');
var notify = require('gulp-notify');
var concat = require('gulp-concat');
var cssmin = require('gulp-cssmin');
var gutil = require('gulp-util');
var rename = require("gulp-rename");
var less = require('gulp-less');
var glob = require('glob');
var path = require('path');
var livereload = require('gulp-livereload');
var fileExists = require('file-exists');
var mocha = require('gulp-mocha');
var istanbul = require('gulp-istanbul');
var isparta = require('isparta');
var coverageEnforcer = require('gulp-istanbul-enforcer');
var which = require('which')

var spawn = require('child_process').spawn;
var argv = require('yargs')
  .default('port', 8000)
  .default('address', 'localhost')
  .argv;

// External dependencies you do not want to rebundle while developing,
// but include in your application deployment
var dependencies = [
];

var options = {
  src: './{{ project_name }}/static/js/index.js',
  dest: './core/public/site_media/js/',
  css: {
    src: './{{ project_name }}/static/less/index.less',
    watch: './{{ project_name }}/static/less/**/*.less',
    dest: './core/public/site_media/css/'
  },
  development: false
}

if (argv._ && argv._[0] === 'deploy') {
  options.development = false
} else {
  options.development = true
}

if (options.development) {
  console.log("Building for development")
  delete process.env['NODE_ENV'];
} else {
  console.log("Building for production")
  process.env['NODE_ENV'] = 'production';
}

var browserifyTask = function () {

  // Our app bundler
  var appBundler = browserify({
    entries: [options.src], // Only need initial file, browserify finds the rest
    transform: [babelify], // We want to convert JSX to normal javascript
    debug: options.development, // Gives us sourcemapping
    cache: {}, packageCache: {}, fullPaths: options.development // Requirement of watchify
  });

  // We set our dependencies as externals on our app bundler when developing
  (options.development ? dependencies : []).forEach(function (dep) {
    appBundler.external(dep);
  });

  // The rebundle process
  var rebundle = function (changedPaths) {
    if (changedPaths && changedPaths.type === 'changed') {
      return arguments.callee([changedPaths.path]);
    }
    if (changedPaths &&
      changedPaths.filter((changedPath) =>
        !changedPath.endsWith('jsx_registry.js')
        ).length === 0
    ) {
      return
    }
    var start = Date.now();
    console.log('Building APP bundle');
    manage_py(['compilejsx', '-o', '{{ project_name }}/static/js/jsx_registry.js'])
    return appBundler.bundle()
        .on('error', function(err) {
          gutil.log(gutil.colors.red(err.message));
          // end this stream
          this.emit('end');
        })
        .pipe(source('index.js'))
        .pipe(gulpif(!options.development, streamify(uglify())))
        .pipe(rename('bundle.js'))
        .pipe(gulp.dest(options.dest))
        .pipe(gulpif(options.development, livereload()))
        .pipe(notify(function () {
          console.log('APP bundle built in ' + (Date.now() - start) + 'ms');
        }));
  };

  // Fire up Watchify when developing
  if (options.development) {
    watchify(appBundler)
        .on('update', rebundle);
    gulp.watch('core/templates/**/*.html', rebundle);
  }

  // We create a separate bundle for our dependencies as they
  // should not rebundle on file changes. This only happens when
  // we develop. When deploying the dependencies will be included
  // in the application bundle
  if (options.development) {

    var vendorsBundler = browserify({
      debug: true,
      require: dependencies
    });

    // Run the vendor bundle
    var start = new Date();
    console.log('Building VENDORS bundle');
    vendorsBundler.bundle()
      .on('error', function(err) {
        gutil.log(gutil.colors.red(err.message));
        // end this stream
        this.emit('end');
      })
      .pipe(source('vendors.js'))
      .pipe(gulpif(!options.development, streamify(uglify())))
      .pipe(gulp.dest(options.dest))
      .pipe(notify(function () {
        console.log('VENDORS bundle built in ' + (Date.now() - start) + 'ms');
      }));
  }

  return rebundle();
};
gulp.task('browserify', browserifyTask);

var cssTask = function () {
    var lessOpts = {
      relativeUrls: true,
    };
    if (options.development) {
      var run = function () {
        var start = Date.now();
        console.log('Building CSS bundle');
        return gulp.src(options.css.src)
          .pipe(gulpif(options.development, livereload()))
          .pipe(concat('index.less'))
          .pipe(less(lessOpts))
          .pipe(rename('bundle.css'))
          .pipe(gulp.dest(options.css.dest))
          .pipe(notify(function () {
            console.log('CSS bundle built in ' + (Date.now() - start) + 'ms');
          }));
      };
      gulp.watch(options.css.watch, run);
      return run();
    } else {
      return gulp.src(options.css.src)
        .pipe(concat('index.less'))
        .pipe(less(lessOpts))
        .pipe(rename('bundle.css'))
        .pipe(cssmin())
        .pipe(gulp.dest(options.css.dest));
    }
};
gulp.task('css', cssTask);

gulp.task('rebuild', ['css', 'browserify'])

function manage_py(args) {
  // Newer versions of npm mess with the PATH, sometimes putting /usr/bin at the front,
  // so make sure we invoke the python from our virtual env explicitly.
  var django_admin = 'django-admin.py'
  var env = Object.assign({}, process.env, {
    'DJANGO_SETTINGS_MODULE': process.env.DJANGO_SETTINGS_MODULE || 'core.settings.local',
  })

  return new Promise((resolve, reject) => {
    which(django_admin, (err, django_admin) => {
        var command;
        // For local development, make sure to run with the virtualenv python
        if (options.development) {
          command = process.env['VIRTUAL_ENV'] + '/bin/python';
          args.splice(0, 0, django_admin)
        // For elastic beanstalk, run with the django-admin.py command
        } else {
          command = django_admin
        }
        if (err) {
            console.error("django-admin.py command not found!")
            return
        }

        spawn(command, args, {
          stdio: "inherit",
          env: env,
        }).on('close', function(code) {
          if (code !== 0) {
            reject(code)
          } else {
            resolve()
          }
        });
    })
  })
}

function start_dev_server(done) {
  console.log("Starting Django runserver http://"+argv.address+":"+argv.port+"/");
  manage_py(["runserver", argv.address+":"+argv.port]).then(
    () => console.log('Django runserver exited normally.'),
    (code) => console.error('Django runserver exited with error code: ' + code)
  )
  done();
}
gulp.task('start_dev_server', ['rebuild'], start_dev_server)

// Starts our development workflow
gulp.task('default', ['start_dev_server'], function (done) {
  livereload.listen();
  done();
});

gulp.task('deploy', ['rebuild']);

gulp.task('test', function () {
  require('babel-core/register');
  return gulp
    .src(['./{{ project_name }}/static/*/**/*.js*'])
    .pipe(istanbul({
      instrumenter: isparta.Instrumenter
      , includeUntested: true
    }))
    .pipe(istanbul.hookRequire())
    .on('finish', function () {
      gulp
        .src('./{{ project_name }}/static/js/test/test_*.js', {read: false})
        .pipe(mocha({
          require: [
            'jsdom-global/register'
          ]
        }))
        .on('error', function(err) {
          gutil.log(gutil.colors.red(err.message));
          // end this stream
          this.emit('end');
        })
        .pipe(istanbul.writeReports({
          dir: './coverage/'
          , reportOpts: {
            dir: './coverage/'
          }
          , reporters: [
            'text'
            , 'text-summary'
            , 'json'
            , 'html'
          ]
        }))
        .pipe(coverageEnforcer({
          thresholds: {
            statements: 80
            , branches: 50
            , lines: 80
            , functions: 50
          }
          , coverageDirectory: './coverage/'
          , rootDirectory: ''
        }))
        .on('error', function(err) {
          gutil.log(gutil.colors.red(err.message));
          // end this stream
          this.emit('end');
        })
      ;
    })
  ;
});
