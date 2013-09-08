{spawn} = require('child_process')


data =
  debug: {}
  child: null


task = (grunt) ->
  files = @filesSrc
  done = @async()
  check = @options().check

  if check
    check = grunt.file.expand(check)
  else
    check = files

  checkDebug = =>
    # check which files have debugger statements
    for file in check
      code = grunt.file.read(file)
      if /^\s*debugger/gm.test(code)
        data.debug[file] = true
      else delete data.debug[file]
    startMocha()

  startMocha = =>
    args = ['--compilers', 'coffee:coffee-script'].concat(files)
    if data.debug and Object.keys(data.debug).length
      args.unshift('--debug-brk')
    opts = stdio: 'inherit'
    data.child = spawn('./node_modules/.bin/mocha', args, opts)
    data.child.on('close', (code) ->
      data.child = null
      done(code == 0))

  if data.child # still running(grunt-contrib-watch?), kill and start again
    data.child.on('close', checkDebug)
    data.child.kill('SIGTERM')
  else
    checkDebug()


module.exports = (grunt) ->
  grunt.registerMultiTask('mocha_debug',
    grunt.file.readJSON('package.json').description, -> task.call(this, grunt))
