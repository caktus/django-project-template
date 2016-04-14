var gulp = require('gulp');
var tasks = require('caktus-gulp-tasks').tasks;

gulp.task('test', tasks.test);
gulp.task('build', tasks.build);
gulp.task('default', tasks.default);
