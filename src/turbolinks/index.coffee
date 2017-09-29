#= require ./BANNER
#= export Turbolinks
#= require_self
#= require ./helpers
#= require ./controller
#= require ./start

@Turbolinks =
  supported: do ->
    # if we support pushState
    window.history.pushState? and
      window.requestAnimationFrame? and
      window.addEventListener?

  visit: (location, options) ->
    Turbolinks.controller.visit(location, options)

  clearCache: ->
    Turbolinks.controller.clearCache()
