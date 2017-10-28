class Turbolinks.History
  constructor: (@delegate) ->

  start: ->
    # 确保我们没有被二次启动
    unless @started
      # calling history.pushState() or history.replaceState() won't trigger a popstate event.
      # The popstate event is only triggered by performing a browser action,
      # such as clicking on the back button (or calling history.back() in JavaScript),
      # when navigating between two history entries for the same document.
      # Browsers tend to handle the popstate event differently on page load.
      # Chrome (prior to v34) and Safari (prior to 10.0) always emit
      # a popstate event on page load, but Firefox doesn't.
      addEventListener("popstate", @onPopState, false)
      # The load event is fired when a resource and its dependent resources have finished loading.
      addEventListener("load", @onPageLoad, false)
      @started = true

  stop: ->
    if @started
      removeEventListener("popstate", @onPopState, false)
      removeEventListener("load", @onPageLoad, false)
      @started = false

  push: (location, restorationIdentifier) ->
    location = Turbolinks.Location.wrap(location)
    @update("push", location, restorationIdentifier)

  replace: (location, restorationIdentifier) ->
    location = Turbolinks.Location.wrap(location)
    @update("replace", location, restorationIdentifier)

  # Event handlers

  onPopState: (event) =>
    if @shouldHandlePopState()
      if turbolinks = event.state?.turbolinks
        location = Turbolinks.Location.wrap(window.location)
        restorationIdentifier = turbolinks.restorationIdentifier
        @delegate.historyPoppedToLocationWithRestorationIdentifier(location, restorationIdentifier)

  onPageLoad: (event) =>
    Turbolinks.defer =>
      @pageLoaded = true

  # Private

  shouldHandlePopState: ->
    # Safari dispatches a popstate event after window's load event, ignore it
    @pageIsLoaded()

  pageIsLoaded: ->
    @pageLoaded or document.readyState is "complete"

  update: (method, location, restorationIdentifier) ->
    state = turbolinks: {restorationIdentifier}
    history[method + "State"](state, null, location)
