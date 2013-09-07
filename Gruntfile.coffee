module.exports = (grunt) ->

  grunt.initConfig
    mocha_debug:
      nodebug: ['test/nodebug.js']
      debug: ['test/debug.js']


  grunt.loadTasks('tasks')

  grunt.registerTask('default', ['mocha_debug'])
