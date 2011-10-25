class ContactPicker extends ContactScroller
  setup: ->
    @register()

  @api
    waitToAppear: (callback) ->
      waiter = setInterval ->
        if window.innerWidth isnt 0
          clearInterval(waiter)
          callback()
      , 100

      setTimeout((-> clearInterval(waiter)), 5000)

    sendGift: (callback) ->
      preview = document.getElementsByName('ok')[0]
      Event(preview).click()

      setTimeout =>
        preview = document.getElementsByClassName('a-wc-na')[0]
        Event(preview).click()

        waitingToSend = setInterval ->
          if window.innerWidth is 0
            clearInterval(waitingToSend)
            clearTimeout(waitingTimeout)
            callback()
        , 100

        waitingTimeout = setTimeout((-> clearInterval(waitingToSend)), 35000)
      , 100

    cancel: (callback) ->
      cancel = document.getElementsByName('cancel')[0]
      Event(cancel).click()
      callback?()

ContactPicker.enable()
