run = (tests) ->
  for own k, v of tests
    if typeof v == 'function'
      if k == '*suiteSetup'
        before(v)
      else if k == '*suiteTeardown'
        after(v)
      else if k == '*setup'
        beforeEach(v)
      else if k == '*teardown'
        afterEach(v)
      else
        if k.match(/^only:/)
          it.only(k.replace(/^only:/, ''), v)
        else if k.match(/^skip:/)
          it.skip(k.replace(/^skip:/, ''), v)
        else
          it(k, v)
    else
      suite = ->
        run(v)
      if k.match(/^only:/)
        describe.only(k, suite)
      else if k.match(/^skip:/)
        describe.skip(k, suite)
      else
        describe(k, suite)


if typeof global != 'undefined'
  global.run = run

if typeof window != 'undefined'
  window.run = run
