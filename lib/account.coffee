class Account
  accounts = {}
  @find: (id) ->
    accounts[id] ||= new @(id)

  @each: (callback) ->
    callback(account) for id, account of accounts

  pageActionData:
    circlePicker:
      setIcon:
        path: 'images/circle.png'
      setTitle:
        title: 'Use the selected users on this page for gift sending'
    giftClaimer:
      setIcon:
        path: 'images/wrapped.png'
      setTitle:
        title: 'Claim your DAL gifts'

  constructor: (@id) ->
    @pageActions = {}
    @tabs = {}

    @gifters = (criteria, callback) ->
      if typeof criteria is 'function'
        callback = criteria
        criteria = {}

      criteria['toAccount'] = id
      (new Gifters()).fetch(conditions: criteria, success: callback)

    @gifters['add'] = (gifterId, attrs, callback) ->
      if typeof attrs is 'function'
        [attrs, callback] = [{}, attrs]
      delete attrs['oid']
      delete attrs['toAccount']

      defaultFn = ->
        gifter.save attrs, success: ->
          callback?(gifter)

      gifter = new Gifter(oid: gifterId, toAccount: id)
      gifter.fetch success: defaultFn, error: defaultFn

    @gifters['sentGift'] = (gifterId, callback) ->
      defaultFn = ->
        sentCount = (gifter.get('sentCount') || 0) + 1
        gifter.save {lastGift: new Date(), sentCount}, success: ->
          callback(gifter) if callback

      gifter = new Gifter(oid: gifterId, toAccount: id)
      gifter.fetch success: defaultFn, error: defaultFn


    @gifts = (criteria, callback) ->
      if typeof criteria is 'function'
        callback = criteria
        criteria = {}

      criteria['toAccount'] = id
      (new Gifts()).fetch(conditions: criteria, success: callback)

    for criteria in ['unclaimed', 'claimed', 'expired', 'error', 'stolen']
      do (criteria) =>
        @gifts[criteria] = (query, callback) =>
          if typeof query is 'function'
            callback = query
            query = {}
          query['status'] = criteria
          @gifts(query, callback)

        @gifts[criteria]['add'] = (token, callback) =>
          defaultFn = =>
            attrs = {status: criteria}
            if criteria isnt 'unclaimed'
              attrs['claimTries'] = (gift.get('claimTries') || 0) + 1

            gift.save attrs, success: =>
              # Take care of possible automated claimer
              @claimFinished() if @giftClaimer && criteria isnt 'unclaimed'

              for tabId, tab of @tabs['GPlus'] || []
                tab.updateGift(token, criteria)

              callback(gift) if typeof callback is 'function'

          gift = new Gift({token, toAccount: id})
          gift.fetch success: defaultFn, error: defaultFn

  claimFinished: ->
    # Get a single unclaimed gift
    @gifts.unclaimed {limit: 1}, (gifts) =>
        # If there was no gift found look for gifts that had
        # errors when trying to claim and pick any that have
        # not been tried 5 times yet and mark them as unclaimed
        # again. The first one found kicks off the claim machine
        # on success and ends it all on error
        if not (gift = gifts.at(0))
          @gifts.error (gifts) =>
              retryable = (gift for gift in gifts.models when (gift.get('claimTries') || 0) < 5)
              if retryable.length > 0
                @gifts.unclaimed.add retryable[0].get('token'), @claimFinished.bind(@)
                  # error: => chrome.tabs.remove(@giftClaimer.id)
                @gifts.unclaimed.add gift.get('token') for gift in retryable[1..-1]
              else
                chrome.tabs.remove(@giftClaimer.id) if @giftClaimer
            # error: =>
            #   chrome.tabs.remove(@giftClaimer.id)
        else
          if @giftClaimer
            chrome.tabs.update(@giftClaimer.id, url: gift.url())
          else
            chrome.tabs.create({url: gift.url(), selected: false}, (tab) => @giftClaimer = tab)
      # error: =>
      #   chrome.tabs.remove(@giftClaimer.id) if @giftClaimer

  claimStart: @::claimFinished

  claimStopped: (tabId) ->
    @giftClaimer = undefined if @giftClaimer?.id is tabId

  sendGifts: (callback, sender) ->
    return unless picker = @tabs['ContactPicker']?[sender.tab.id]

    picker.waitToAppear =>
      @gifters (all) =>
        all = (gifter.get('oid') for gifter in all.models when gifter.isGiftable())

        picker.selectUsers all[0...50], (selected) =>
          picker.sendGift =>
            @gifters.sentGift(oid) for oid in selected
            @tabs['DAL']?[sender.tab.id]?.continueSendingGifts() if all.length > 50


  registerTab: (name, callback, sender) ->
    collection = @tabs[name] ||= {}
    return if collection[sender.tab.id]

    switch name
      when 'ContactPicker'
        # Only allow the contact picker, which attaches itself to a generic
        # google contact picker to only register itself when coming from a tab
        # that has the DAL game loaded in it
        return unless /plus\.google\.com\/games\/867517237916/.test(sender.tab.url)

    instance = new window[name](sender.tab.id)
    collection[sender.tab.id] = instance

  unregisterTab: (name, callback, sender) ->
    delete @tabs[name][sender.tab.id] if @tabs[name]

  showPageAction: (type, callback, sender) ->
    if not @pageActions[sender.tab.id] || @pageActions[sender.tab.id] is type
      clone = {}
      for method, data of @pageActionData[type]
        clone[method] = {}
        clone[method][key] = value for key, value of data
        clone[method].tabId = sender.tab.id

      applySettings = ->
        chrome.pageAction.show(sender.tab.id)
        for method, data of clone
          tmp = {}
          tmp[key] = value for key, value of data
          chrome.pageAction[method](tmp)

      if @pageActions[sender.tab.id] is type
        applySettings()
      else
        @pageActions[sender.tab.id] = type
        count = 0
        pageActionTimer = setInterval =>
          if ++count >= 10 || @pageActions[sender.tab.id] isnt type
            clearInterval(pageActionTimer)
          else
            applySettings()
        , 100


  hidePageAction: (type, callback, sender) ->
    if @pageActions[sender.tab.id] is type
      chrome.pageAction.hide(sender.tab.id)
      delete @pageActions[sender.tab.id]

if window.location.protocol isnt 'chrome-extension:'
  do ->
    queue = []
    accountId = null
    idDiv = document.createElement('div')
    idDiv.style.display = 'none'
    idDiv.setAttribute('onclick', '(' + ((el) ->
      alertIdReady = (id) ->
        el.setAttribute('oid', id)
        event = document.createEvent('Events')
        event.initEvent('gplusid', true, true)
        el.dispatchEvent(event)

      if OZ_initData?[2]?[0]?
        alertIdReady(OZ_initData[2][0])
      else
        tries = 0
        postId = (user) ->
          tries++
          if user.id
            alertIdReady(user.id)
          else if user?.error?.message is 'quota exceeded'
            setTimeout((-> google.plusone.api('/people/me', postId)), 1000 * 60 * 5)
          else if tries < 5
            setTimeout((-> google.plusone.api('/people/me', postId)), 100)

        google.plusone.api '/people/me', postId
    ).toString() + ')(this);')
    document.body.appendChild(idDiv)

    idDiv.addEventListener 'gplusid', ->
      Account.id = accountId = idDiv.getAttribute('oid')
      for item in queue
        item[0].accountId = accountId
        chrome.extension.sendRequest(item...)
      document.body.removeChild(idDiv)

    # Gift google some time to do its login so we don't
    # hit the url too much, e.g. once unauthed and once authed
    # setTimeout (-> Event(idDiv).click()), 100

    nullFn = ->

    walkMethodTree = (anchor, root, prefix = '') ->
      for method, body of root when typeof body is 'function'
        do (method) ->
          anchor[method] = (args...) ->
            if typeof args[args.length - 1] is 'function'
              callback = args[args.length - 1]
              args = args[0...-1]
            else
              callback = nullFn

            # Add the user account identifier from G+
            signature = [{method: "#{prefix}#{method}", args, accountId}, callback]
            if accountId
              try
                chrome.extension.sendRequest(signature...)
            else
              # Wait until it is needed to get the account id
              if queue.length is 0
                queue.push signature
                Event(idDiv).click()
              else
                queue.push signature

        walkMethodTree(anchor[method], root[method], "#{prefix}#{method}.")

    walkMethodTree(Account, new Account())
