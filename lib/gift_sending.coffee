class ContactPicker extends TabApi
  setup: ->
    @register()

  @api
    waitToAppear: ->
      if window.innerWidth is 0
        @waitingToDetect = setTimeout(@waitToAppear.bind(@), 100)
      else
        @waitingToDetect = false
        Account.gifters (allGifters) =>
          @gifters = {}
          count = 0

          aDayAgo = new Date() - 1000 * 60 * 60 * 24
          for gifter in allGifters
            if not gifter.lastGift || gifter.lastGift < aDayAgo
              @gifters[gifter.account] = true
              break if ++count >= 50

          @scroller = document.getElementsByClassName('NP')[0]

          originalScroll = @scroller.onscroll
          @scroller.onscroll = =>
            @pickVisible()
            originalScroll.apply(window, [arguments...]) if originalScroll

          @pickVisible()
          @scrollContacts()

  pickVisible: ->
    for el in [document.getElementsByClassName('cl')...]
      oid = el.getAttribute('oid')
      if @gifters[oid]
        Event(el).mousedown().mouseup()

  scrollContacts: ->
    curScroll = @scroller.scrollTop

    @scroller.scrollTop += 200
    if @scroller.scrollTop is curScroll
      @sendGift()
      # setTimeout( ->
      #   chrome.extension.sendRequest availableGifters: true, (gifters) ->
      #     for gifter in gifters when gifter in selected
      #       console.log("Not selecting https://plus.google.com/#{gifters[i]}/posts")
      # , 300)
    else
      @scrollTimer = setTimeout(@scrollContacts.bind(@), 100)


  sendGift: ->
    preview = document.getElementsByClassName('a-wc-na')
    Event(preview[0]).click()

    setTimeout =>
      preview = document.getElementsByClassName('a-wc-na')
      Event(preview[0]).click()

      count = 0
      for oid, _ of @gifters
        count++
        Account.gifters.sentGift(oid)

      waitingToSend = setInterval ->
        if window.innerWidth is 0
          clearInterval(waitingToSend)
          Account.continueSendingGifts() if count > 50
      , 100

      setTimeout((-> clearInterval(waitingToSend)), 15000)
    , 100

ContactPicker.enable()
