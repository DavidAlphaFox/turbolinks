#= require ./BANNER
#= export Turbolinks
#= require_self
#= require ./helpers
#= require ./controller
#= require ./start

## 全局设定 Turbolinks
@Turbolinks =
  supported: do ->
    # if we support pushState
    # if we support requestAnimationFrame
    # if we support addEventListener
    # if we support features above we can use turbolinks
    window.history.pushState? and
      window.requestAnimationFrame? and
      window.addEventListener?

  visit: (location, options) ->
    Turbolinks.controller.visit(location, options)

  clearCache: ->
    Turbolinks.controller.clearCache()
