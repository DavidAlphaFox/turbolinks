#= require ./location
#= require ./browser_adapter
#= require ./history
#= require ./view
#= require ./scroll_manager
#= require ./snapshot_cache
#= require ./visit

class Turbolinks.Controller
  constructor: ->
    ## History管理器，依赖popstate和load事件
    @history = new Turbolinks.History this
    @view = new Turbolinks.View this
    @scrollManager = new Turbolinks.ScrollManager this
    @restorationData = {}
    @clearCache()

  start: ->
    # ensure pushState is supported and we not started
    if Turbolinks.supported and not @started
      # add a global event listener on click and DOMContentLoaded
      ## 监听点击事件
      addEventListener("click", @clickCaptured, true)
      ## 整个页面被重新加载的时候才会产生DOMContentLoaded事件
      ## The DOMContentLoaded event is fired when the initial HTML document has been completely
      ## loaded and parsed, without waiting for stylesheets, images, and subframes to finish
      ## loading. A very different event load should be used only to detect a fully-loaded page.
      ## It is an incredibly popular mistake to use load
      ## where DOMContentLoaded would be much more appropriate, so be cautious.
      addEventListener("DOMContentLoaded", @pageLoaded, false)
      @scrollManager.start()
      @startHistory()
      @started = true
      @enabled = true

  disable: ->
    @enabled = false

  stop: ->
    if @started
      removeEventListener("click", @clickCaptured, true)
      removeEventListener("DOMContentLoaded", @pageLoaded, false)
      @scrollManager.stop()
      @stopHistory()
      @started = false

  clearCache: ->
    @cache = new Turbolinks.SnapshotCache 10

  visit: (location, options = {}) ->
    location = Turbolinks.Location.wrap(location)
    if @applicationAllowsVisitingLocation(location)
      if @locationIsVisitable(location)
        action = options.action ? "advance"
        @adapter.visitProposedToLocationWithAction(location, action)
      else
        window.location = location

  startVisitToLocationWithAction: (location, action, restorationIdentifier) ->
    if Turbolinks.supported
      restorationData = @getRestorationDataForIdentifier(restorationIdentifier)
      @startVisit(location, action, {restorationData})
    else
      window.location = location

  # History

  startHistory: ->
    @location = Turbolinks.Location.wrap(window.location)
    @restorationIdentifier = Turbolinks.uuid()
    @history.start()
    @history.replace(@location, @restorationIdentifier)

  stopHistory: ->
    @history.stop()

  pushHistoryWithLocationAndRestorationIdentifier: (location, @restorationIdentifier) ->
    @location = Turbolinks.Location.wrap(location)
    @history.push(@location, @restorationIdentifier)

  replaceHistoryWithLocationAndRestorationIdentifier: (location, @restorationIdentifier) ->
    @location = Turbolinks.Location.wrap(location)
    @history.replace(@location, @restorationIdentifier)

  # History delegate

  historyPoppedToLocationWithRestorationIdentifier: (location, @restorationIdentifier) ->
    if @enabled
      restorationData = @getRestorationDataForIdentifier(@restorationIdentifier)
      @startVisit(location, "restore", {@restorationIdentifier, restorationData, historyChanged: true})
      @location = Turbolinks.Location.wrap(location)
    else
      @adapter.pageInvalidated()

  # Snapshot cache

  getCachedSnapshotForLocation: (location) ->
    snapshot = @cache.get(location)
    snapshot.clone() if snapshot

  shouldCacheSnapshot: ->
    @view.getSnapshot().isCacheable()

  cacheSnapshot: ->
    if @shouldCacheSnapshot()
      @notifyApplicationBeforeCachingSnapshot()
      snapshot = @view.getSnapshot()
      @cache.put(@lastRenderedLocation, snapshot.clone())

  # Scrolling

  scrollToAnchor: (anchor) ->
    if element = document.getElementById(anchor)
      @scrollToElement(element)
    else
      @scrollToPosition(x: 0, y: 0)

  scrollToElement: (element) ->
    @scrollManager.scrollToElement(element)

  scrollToPosition: (position) ->
    @scrollManager.scrollToPosition(position)

  # Scroll manager delegate

  scrollPositionChanged: (scrollPosition) ->
    restorationData = @getCurrentRestorationData()
    restorationData.scrollPosition = scrollPosition

  # View

  render: (options, callback) ->
    @view.render(options, callback)

  viewInvalidated: ->
    @adapter.pageInvalidated()

  viewWillRender: (newBody) ->
    @notifyApplicationBeforeRender(newBody)

  viewRendered: ->
    @lastRenderedLocation = @currentVisit.location
    @notifyApplicationAfterRender()

  # Event handlers
  ## 绑定到window对象上
  pageLoaded: =>
    ## 得到当前所在的url路径
    @lastRenderedLocation = @location
    @notifyApplicationAfterPageLoad()

  ## 绑定到window对象上
  clickCaptured: =>
    ## 先移除clickBubbled，再添加clickBubbled到click事件上
    removeEventListener("click", @clickBubbled, false)
    addEventListener("click", @clickBubbled, false)

  clickBubbled: (event) =>
    if @enabled and @clickEventIsSignificant(event)
      if link = @getVisitableLinkForNode(event.target)
        if location = @getVisitableLocationForLink(link)
          if @applicationAllowsFollowingLinkToLocation(link, location)
            event.preventDefault()
            action = @getActionForLink(link)
            @visit(location, {action})

  # Application events

  applicationAllowsFollowingLinkToLocation: (link, location) ->
    event = @notifyApplicationAfterClickingLinkToLocation(link, location)
    not event.defaultPrevented

  applicationAllowsVisitingLocation: (location) ->
    event = @notifyApplicationBeforeVisitingLocation(location)
    not event.defaultPrevented

  notifyApplicationAfterClickingLinkToLocation: (link, location) ->
    Turbolinks.dispatch("turbolinks:click", target: link, data: { url: location.absoluteURL }, cancelable: true)

  notifyApplicationBeforeVisitingLocation: (location) ->
    Turbolinks.dispatch("turbolinks:before-visit", data: { url: location.absoluteURL }, cancelable: true)

  notifyApplicationAfterVisitingLocation: (location) ->
    Turbolinks.dispatch("turbolinks:visit", data: { url: location.absoluteURL })

  notifyApplicationBeforeCachingSnapshot: ->
    Turbolinks.dispatch("turbolinks:before-cache")

  notifyApplicationBeforeRender: (newBody) ->
    Turbolinks.dispatch("turbolinks:before-render", data: {newBody})

  notifyApplicationAfterRender: ->
    Turbolinks.dispatch("turbolinks:render")

  notifyApplicationAfterPageLoad: (timing = {}) ->
    ## 让Turbolinks 分发turbolinks:load事件
    Turbolinks.dispatch("turbolinks:load", data: { url: @location.absoluteURL, timing })

  # Private

  startVisit: (location, action, properties) ->
    @currentVisit?.cancel()
    @currentVisit = @createVisit(location, action, properties)
    @currentVisit.start()
    @notifyApplicationAfterVisitingLocation(location)

  createVisit: (location, action, {restorationIdentifier, restorationData, historyChanged} = {}) ->
    visit = new Turbolinks.Visit this, location, action
    visit.restorationIdentifier = restorationIdentifier ? Turbolinks.uuid()
    visit.restorationData = Turbolinks.copyObject(restorationData)
    visit.historyChanged = historyChanged
    visit.referrer = @location
    visit

  visitCompleted: (visit) ->
    @notifyApplicationAfterPageLoad(visit.getTimingMetrics())

  clickEventIsSignificant: (event) ->
    not (
      event.defaultPrevented or
      event.target.isContentEditable or
      event.which > 1 or
      event.altKey or
      event.ctrlKey or
      event.metaKey or
      event.shiftKey
    )

  getVisitableLinkForNode: (node) ->
    if @nodeIsVisitable(node)
      Turbolinks.closest(node, "a[href]:not([target]):not([download])")

  getVisitableLocationForLink: (link) ->
    location = new Turbolinks.Location link.getAttribute("href")
    location if @locationIsVisitable(location)

  getActionForLink: (link) ->
    link.getAttribute("data-turbolinks-action") ? "advance"

  nodeIsVisitable: (node) ->
    if container = Turbolinks.closest(node, "[data-turbolinks]")
      container.getAttribute("data-turbolinks") isnt "false"
    else
      true

  locationIsVisitable: (location) ->
    location.isPrefixedBy(@view.getRootLocation()) and location.isHTML()

  getCurrentRestorationData: ->
    @getRestorationDataForIdentifier(@restorationIdentifier)

  getRestorationDataForIdentifier: (identifier) ->
    @restorationData[identifier] ?= {}
