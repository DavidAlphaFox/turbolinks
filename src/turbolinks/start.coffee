Turbolinks.start = ->
  if installTurbolinks()
    ## 创建
    Turbolinks.controller ?= createController()
    Turbolinks.controller.start()

installTurbolinks = ->
  # 设置turbolinks
  window.Turbolinks ?= Turbolinks
  moduleIsInstalled()

createController = ->
  controller = new Turbolinks.Controller
  controller.adapter = new Turbolinks.BrowserAdapter(controller)
  controller

moduleIsInstalled = ->
  window.Turbolinks is Turbolinks

Turbolinks.start() if moduleIsInstalled()
