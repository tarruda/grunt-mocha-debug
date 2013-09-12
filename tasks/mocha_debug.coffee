{spawn} = require('child_process')
express = require('express')
path = require('path')
fs = require('fs')
phantomjsWrapper = require('phantomjs-wrapper')
mocha = require('mocha')
{EventEmitter} = require('events')


r = mocha.reporters
reporterMap =
  'dot': r.Dot
  'doc': r.Doc
  'tap': r.TAP
  'json': r.JSON
  'html': r.HTML
  'list': r.List
  'min': r.Min
  'spec': r.Spec
  'nyan': r.Nyan
  'xunit': r.XUnit
  'markdown': r.Markdown
  'progress': r.Progress
  'landing': r.Landing
  'json-cov': r.JSONCov
  'html-cov': r.HTMLCov
  'json-stream': r.JSONStream
  'teamcity': r.Teamcity


data =
  debug: {}
  child: null

pluginRoot = __dirname

while not fs.existsSync(path.join(pluginRoot, 'package.json'))
  pluginRoot = path.dirname(pluginRoot)

pluginRoot = path.relative(process.cwd(), pluginRoot)

mochaRoot = path.join(pluginRoot, 'node_modules', 'mocha')
mochaCss = path.join(mochaRoot, 'mocha.css')
mochaJs = path.join(mochaRoot, 'mocha.js')
mochaBin = path.join(mochaRoot, 'bin', 'mocha')


runner = taskDone = testHtml = server = phantomjs = page = reporter = null


setupServer = (grunt, options, done) ->
  app = express()
  app.get(options.testUrl, (req, res) =>
    res.send(testHtml)
  )
  app.use(express.static(process.cwd()))
  server = app.listen(options.listenPort, options.listenAddress, =>
    setupPhantomJS.call(this, grunt, options, done)
  )


setupPhantomJS = (grunt, options, done) ->
  phantomjsWrapper(timeout: 300000, (err, phantom) =>
    phantomjs = phantom
    phantomjs.on('closed', =>
      grunt.log.writeln('Phantomjs exited due to inactivity')
      phantomjs = null
    )
    phantomjs.createPage((err, webpage) =>
      page = webpage
      suites = []
      page.on('consoleMessage', (msg) =>
        grunt.log.warn("PhantomJS console: #{msg}")
      )
      page.on('alert', (msg) =>
        grunt.log.warn("PhantomJS alert: #{msg}")
      )
      page.on('callback', (event) =>
        {test, type, err} = event
        if test
          slow = test.slow
          test.slow = -> slow
          fullTitle = test.fullTitle
          test.fullTitle = -> fullTitle
          test.parent = suites[suites.length - 1] || null
        switch type
          when 'suite'
            suites.push(test)
          when 'suite end'
            suites.pop()
        # forward events to the fake runner
        runner.emit(type, test, err)
        if type == 'end'
          taskDone()
      )
      page.on('error', (err) =>
        grunt.log.error("PhantomJS error: #{err.message}")
        taskDone(false)
      )
      page.on('resourceError', (err) =>
        grunt.log.error("PhantomJS error: failed to load #{err.url}")
        taskDone(false)
      )
      {listenAddress: address, testUrl: url} = options
      {port} = server.address()
      page.open("http://#{address}:#{port}#{url}", => )
    )
  )


phantomTask = (grunt, options, done) ->
  page.reload()


preparePhantomTest = (grunt, options, done) ->
  taskDone = done
  Reporter = reporterMap[options.reporter.toLowerCase()]
  runner = new EventEmitter()
  reporter = new Reporter(runner)
  testHtml = generateHtml.call(this, grunt, options)


nodeTask = (grunt, options, done) ->
  files = options.files
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
      else
        delete data.debug[file]
    startMocha()

  startMocha = =>
    dir = path.dirname(__dirname)
    files.unshift(path.join(dir, 'runner.coffee'))
    args = [
      '--reporter', options.reporter
      '--compilers', 'coffee:coffee-script'
    ].concat(args, files)
    if data.debug and Object.keys(data.debug).length
      args.unshift('--debug-brk')
    opts = stdio: 'inherit'
    data.child = spawn(mochaBin, args, opts)
    data.child.on('close', (code) ->
      data.child = null
      done(code == 0))

  if data.child # still running(grunt-contrib-watch?), kill and start again
    data.child.on('close', checkDebug)
    data.child.kill('SIGTERM')
  else
    checkDebug()


generateHtml = (grunt, options) ->
  files = options.files
  tags = []
  for file in files
    tags.push("<script src=#{file}></script>")

  body = options.body or
    """
    <div id="mocha">
      <script src="#{mochaJs}"></script>
      <script>
      #{mochaBridge}
      </script>
      #{tags.join('\n')}
      <script>
      mocha.run();
      </script>
    </div>
    """

  css = ''
  if options.enableHtmlReporter
    css = "<link rel=\"stylesheet\" href=\"#{mochaCss}\" />"
       
  return (
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>test runner</title>
        <meta charset="utf-8">
        #{css}
      </head>
      <body>
      #{body}
      </body>
    </html>
    """
  )


# based on https://github.com/kmiyashiro/grunt-mocha/blob/master/phantomjs/bridge.js
mochaBridge = (->
  mochaInstance = window.Mocha || window.mocha
  HtmlReporter = mochaInstance.reporters.HTML

  GruntReporter = (runner) ->

    # Setup HTML reporter to output data on the screen
    if mochaOptions?.enableHtmlReporter
      HtmlReporter.call(this, runner)

    # listen for each mocha event
    events = [
      'start'
      'test'
      'test end'
      'suite'
      'suite end'
      'fail'
      'pass'
      'pending'
      'end'
    ]

    for event in events
      do (event) ->
        runner.on(event, (test, err) ->
          ev = err: err, type: event
          if test
            ev.test =
              title: test.title
              fullTitle: test.fullTitle()
              slow: test.slow()
          callPhantom(ev)
        )

  mocha.setup(
    reporter: if callPhantom? then GruntReporter else HtmlReporter
    ui: mochaOptions?.ui or 'bdd'
    ignoreLeaks: mochaOptions?.ignoreLeaks or false
  )

).toString()


mochaBridge = "(#{mochaBridge})();"


module.exports = (grunt) ->
  grunt.registerMultiTask('mocha_debug', grunt.file.readJSON('package.json').description, ->
    options = @options(
      reporter: 'dot'
      phantomjs: false
      startServer: true
      listenAddress: "127.0.0.1"
      listenPort: 0
      testUrl: '/index.html'
    )

    done = @async()

    if not options.src
      grunt.log.error('Need to specify at least one source file')
      return done(false)

    options.files = grunt.file.expand(options.src)

    if options.phantomjs
      preparePhantomTest.call(this, grunt, options, done)
      if not phantomjs or phantomjs.closed
        if options.startServer and not server
          setupServer.call(this, grunt, options, done)
        else
          setupPhantomJS.call(this, grunt, options, done)
      else
        phantomTask.call(this, grunt, options, done)
    else
      nodeTask.call(this, grunt, options, done)
  )
