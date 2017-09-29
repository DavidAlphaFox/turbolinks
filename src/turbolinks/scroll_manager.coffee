class Turbolinks.ScrollManager
  constructor: (@delegate) ->
    @onScroll = Turbolinks.throttle(@onScroll)

  start: ->
    unless @started
      addEventListener("scroll", @onScroll, false)
      @onScroll()
      @started = true

  stop: ->
    if @started
      removeEventListener("scroll", @onScroll, false)
      @started = false

  scrollToElement: (element) ->
    element.scrollIntoView()

  scrollToPosition: ({x, y}) ->
    window.scrollTo(x, y)

  onScroll: (event) =>
    ## when scroll the page, we will scroll the page auto
    @updatePosition(x: window.pageXOffset, y: window.pageYOffset)

  # Private

  updatePosition: (@position) ->
    @delegate?.scrollPositionChanged(@position)
