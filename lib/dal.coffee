class DAL extends TabApi
  setup: ->
    @register()

    if token = @giftClaimToken()
      @reportGiftStatus (message) ->
        if /\b(successfully|already)\b/.test message
          Account.gifts.claimed.add(token)
        else if /\berror\b/i.test message
          Account.gifts.error.add(token)
        else if /\bexpired\b/.test message
          Account.gifts.expired.add(token)
        else if /\bstolen\b/.test message
          # We couldn't find that gift in our databases. A hurlock must have stolen it!
          Account.gifts.stolen.add(token)

    @hookAutoGiftSending()

  giftClaimToken: ->
    parseParams = (string) ->
      results = {}
      for item in string.slice(1, -1).split('&')
        [key, value] = item.split('=')
        results[key] = value
      results

    params = parseParams(window.location.hash)?['view-params']

    try
      params = JSON.parse(decodeURIComponent(params))
      token = params.token if params?.page is 'acceptedGift'

    token

  reportGiftStatus: (callback) ->
    giftCheck = setInterval ->
      confirmation = document.getElementsByClassName('giftPage')
      if confirmation.length is 1
        clearInterval giftCheck
        callback?(confirmation[0].innerText)
    , 1000

    # Set a timeout for how long to wait for gift claim before skipping
    setTimeout ->
      clearInterval giftCheck
      callback('error')
    , 15000

  hookAutoGiftSending: ->
    giftSending = setInterval ->
      return unless tabs = document.getElementById('tabs')
      clearInterval giftSending

      link = document.createElement('a')
      link.setAttribute('class', 'tab')
      link.setAttribute('onclick', '(' + ((el)->
        replaceClass = (original, replacement, elements) ->
          comparator = new RegExp("(\\s|^)#{original}(\\s|$)", 'i')
          for node in elements when comparator.test(node.className)
            classes = node.className.split(' ')
            classes = (klass for klass in classes when klass isnt '' and klass isnt original)
            classes.push(replacement)
            node.className = classes.join(' ')

        requestGifting true, url: giftingParams.url, data: giftingParams.data, success: (data) ->
          onGiftContainerShow(data)

          buttons = document.getElementById('giftForm').getElementsByClassName('giftHeadline')[0]
          button = buttons.childNodes[1]
          button.setAttribute('id', 'dal-send-autogift')
          button.setAttribute('value', 'Send to All >>')
          button.setAttribute('onclick', '(' + ((el) ->
            event = document.createEvent('Events')
            event.initEvent('user:autogift', true, true)
            el.dispatchEvent(event)
          ).toString() + ')(this); ' + button.getAttribute('onclick'))

          form = document.getElementById('giftForm')
          locked = Array::slice.apply(form.getElementsByClassName('locked'))

          replaceClass('locked', 'available', locked)

          for item in locked
            item.setAttribute('onclick', "selectTheGift(#{item.id.match(/cell(\d+)/)[1]});")

          for item in Array::slice.apply(form.getElementsByClassName('giftingLevelRestriction'))
            item.parentElement.removeChild(item)


        # Setup the visual queue of which tab the interface is on
        # for sibling in el.parentElement.childNodes when /(\s|^)tab(\s|$)/.test(sibling.className)
        #   sibling.className = sibling.className.replace(/\s*selectedTab\s*/, '')
        replaceClass('selectedTab', '', el.parentElement.childNodes)

        el.className = "#{el.className} selectedTab"
      ).toString() + ')(this);')

      link.innerText = 'Auto Gift'
      tabs.insertBefore(link, tabs.childNodes[0])

      window.addEventListener 'user:autogift', (event) =>
        Account.sendGifts(@sentGifts, @totalGifters)

    , 1000

  @api
    continueSendingGifts: (@sentGifts, @totalGifters) ->
      document.getElementById('feedback').style.display = 'none'
      Event(document.getElementById('dal-send-autogift')).click()

    doneSendingGifts: ->
      delete @sentGifts
      delete @totalGifters
      document.getElementById('feedback').style.display = 'none'
      Event(document.getElementsByClassName('giftButton giftSkip')[0]).click()

DAL.enable()

