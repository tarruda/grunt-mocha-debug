module.exports = (grunt) ->

  grunt.initConfig
    mocha_debug:
      nodebug:
        options: check: 'test/nodebug.*'
        src: 'test/nodebug.js'
      debug:
        options: check: 'test/debug.*'
        src: 'test/debug.js'


  grunt.loadTasks('tasks')

  grunt.registerTask('default', ['mocha_debug'])
