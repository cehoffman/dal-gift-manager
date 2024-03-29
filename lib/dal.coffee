class DAL extends TabApi
  setup: ->
    @register()

    @getGiftStatus(token, @reportGiftStatus) if token = @giftClaimToken()
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

  getGiftStatus: (token, callback) ->
    tries = 0
    callback = (->) unless typeof callback is 'function'

    giftCheck = setInterval ->
      confirmation = document.getElementsByClassName('giftPage')
      if confirmation.length is 1
        clearInterval giftCheck
        callback(token, confirmation[0].innerText)
      else if ++tries > 15
        clearInterval giftCheck
        callback(token, 'error')
    , 1000

  reportGiftStatus: (token, message) ->
    if /\b(successfully|already)\b/.test message
      Account.gifts.claimed.add(token)
    else if /\berror\b/i.test message
      Account.gifts.error.add(token)
    else if /\bexpired\b/.test message
      Account.gifts.expired.add(token)
    else if /\bstolen\b/.test message
      # We couldn't find that gift in our databases. A hurlock must have stolen it!
      Account.gifts.stolen.add(token)


  hookAutoGiftSending: ->
    self = this
    giftSending = setInterval ->
      return unless tabs = document.getElementById('tabs')
      clearInterval giftSending

      link = document.createElement('a')
      link.setAttribute('class', 'tab')
      link.setAttribute('onclick', '(' + ((el, unlockGifts)->
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

          if unlockGifts
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
      ).toString() + ")(this, #{/mgcofonngbfflpmikhcmkonibglghcaf/.test(chrome.extension.getURL(''))});")

      link.innerText = 'Auto Gift'
      tabs.insertBefore(link, tabs.childNodes[0])

      window.addEventListener 'user:autogift', (event) ->
        Account.sendGifts(self.sentGifts, self.totalGifters)

    , 1000

  @api
    claimGift: (token) ->
      giftDiv = document.createElement('div')
      giftDiv.style.display = 'none'
      giftDiv.setAttribute 'onclick', '(' + ((el, giftToken) ->
        requestGifting true,
          url: "#{giftingParams.url}/acceptedGift"
          data: {giftToken, signed_request: giftingParams.data.signed_request}
          success: (data) ->
            onGiftContainerShow(data)
            $('#gameContent').show('slow', -> iframes.resize(height: document.body.scrollHeight))

            event = document.createEvent('Events')
            event.initEvent('user:gift-claim', false, true)
            el.dispatchEvent(event)
        ).toString() + ")(this, #{JSON.stringify(token)});"

      document.body.appendChild(giftDiv)

      giftDiv.addEventListener 'user:gift-claim', (event) =>
        @getGiftStatus(token, @reportGiftStatus)
        giftDiv.parentElement.removeChild(giftDiv)

      Event(giftDiv).click()

    continueSendingGifts: (@sentGifts, @totalGifters) ->
      document.getElementById('feedback').style.display = 'none'
      Event(document.getElementById('dal-send-autogift')).click()

    doneSendingGifts: ->
      delete @sentGifts
      delete @totalGifters
      document.getElementById('feedback').style.display = 'none'
      Event(document.getElementsByClassName('giftButton giftSkip')[0]).click()

DAL.enable()

