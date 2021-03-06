#= require ./snapshot
#= require ./snapshot_renderer
#= require ./error_renderer

class Turbolinks.View
  constructor: (@delegate) ->
    ## 得到页面的根元素
    @element = document.documentElement

  getRootLocation: ->
    @getSnapshot().getRootLocation()

  getSnapshot: ->
    ## 生成快照
    Turbolinks.Snapshot.fromElement(@element)

  render: ({snapshot, error, isPreview}, callback) ->
    @markAsPreview(isPreview)
    if snapshot?
      @renderSnapshot(snapshot, callback)
    else
      @renderError(error, callback)

  # Private

  markAsPreview: (isPreview) ->
    if isPreview
      @element.setAttribute("data-turbolinks-preview", "")
    else
      @element.removeAttribute("data-turbolinks-preview")

  renderSnapshot: (snapshot, callback) ->
    Turbolinks.SnapshotRenderer.render(@delegate, callback, @getSnapshot(), Turbolinks.Snapshot.wrap(snapshot))

  renderError: (error, callback) ->
    Turbolinks.ErrorRenderer.render(@delegate, callback, error)
