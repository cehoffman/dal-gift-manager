giftHash = (url) ->
  token = url.match(/%22%3A%22(.*)%22%7D/)
  if token
    try
      token = JSON.parse(atob(token[1]))
    catch e
      try
        token = JSON.parse(atob(token[1][0...-1]))
      catch e

    token.token if token.page is 'acceptedGift'

Event = (element) ->
  dispatch = (type, subtype, args...) ->
    event = document.createEvent(type)
    event.initEvent(subtype, args...)
    element.dispatchEvent(event)
  mousedown: ->
    dispatch('MouseEvents', 'mousedown', true, true)
    @
  mouseup: ->
    dispatch('MouseEvents', 'mouseup', true, true)
    @
  click: ->
    dispatch('MouseEvents', 'click', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
    @
  custom: (type, args...)->
    dispatch('Events', type, args...)

class TabApi
  @rootApi: 'chrome-extension:'
  @api: (methods) ->
    nullFn = ->
    enableRpc = (new RegExp(@rootApi, 'i')).test(window.location.href)

    for method, body of methods
      if enableRpc
        do (method) =>
          @::[method] = (args...) ->
            if typeof args[args.length - 1] is 'function'
              callback = args[args.length - 1]
              args = args[0...-1]
            else
              callback = nullFn

            chrome.tabs.sendRequest(@tabId, {method, args, class: @name()}, callback)
      else
        @::[method] = body

    unless enableRpc
      @enable = ->
        tab = new @()
        tab.setup()

        originalUnload = window.onbeforeunload
        window.onbeforeunload = =>
          tab.unregister()
          originalUnload.apply(window, [arguments...]) if originalUnload

        chrome.extension.onRequest.addListener (request, sender, callback) ->
          if request.class is tab.name()
            tab[request.method]?([request.args..., callback]...)

  @enable: ->

  constructor: (@tabId) ->

  name: ->
    @_name ||= @constructor.toString().match(/function\s*([^(\s]+)/)[1]

  register: ->
    Account.registerTab(@name())

  unregister: ->
    name = @constructor.toString().match(/function\s*([^(\s]+)/)[1]
    Account.unregisterTab(@name())

  setup: ->

class ContactScroller extends TabApi
  @api
    selectUsers: (users, callback) ->
      usersHash = {}
      usersHash[oid] = true for oid in users
      selected = []

      pickVisible = ->
        for el in [document.getElementsByClassName('cl')...]
          oid = el.getAttribute('oid')
          if usersHash[oid]
            selected.push(oid)
            Event(el).mousedown().mouseup()

      @scroll
        setup: pickVisible
        step: pickVisible
        teardown: -> callback?(selected)

  scroll: (callbacks) ->
    scroller = document.getElementsByClassName('NP')[0]
    unless scroller
      console.log(window.location.href)
      console.log(document.getElementsByClassName('NP'))

    scroller.scrollTop = 0

    setTimeout ->
      callbacks?.setup?()

      originalScroll = scroller.onscroll
      scroller.onscroll = =>
        callbacks?.step?()
        originalScroll.apply(window, [arguments...]) if originalScroll

      scrollTimer = null
      scrollFn = ->
        curScroll = scroller.scrollTop

        scroller.scrollTop += 200
        if scroller.scrollTop is curScroll
          scroller.onscroll = originalScroll
          callbacks?.teardown?()
        else
          scrollTimer = setTimeout(scrollFn, 100)

      scrollFn()
    , 100

