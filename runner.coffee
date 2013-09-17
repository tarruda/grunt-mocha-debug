mochaRun = (tests) ->
  for own k, v of tests
    if typeof v == 'function'
      if k == 'before'
        before(v)
      else if k == 'after'
        after(v)
      else if k == 'beforeEach'
        beforeEach(v)
      else if k == 'afterEach'
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
  global.run = mochaRun

if typeof window != 'undefined'
  window.run = mochaRun
