class Account
  # Indexed by tab id
  tab2account = {}
  accounts = {}

  @find: (id) ->
    tab2account[id] ||= new @()

  @remove: (id) ->
    tab2account[id]?.claimStopped(id)
    accountId = tab2account[id]?.id
    delete tab2account[id]

    if accountId
      # If at least one tab has this account open in it then keep the
      # account instance around. Otherwise it should be deleted
      return for tabId, account of tab2account when account.id is accountId
      delete accounts[accountId]

  @each: (callback) ->
    callback(account) for id, account of tab2account

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

  setId: (@id, callback, sender) ->
    if not accounts[@id]
      console.log(sender.tab.id, 'registering new account', @id)
      accounts[@id] = this
    tab2account[sender.tab.id] = accounts[@id]

  constructor: ->
    self = this
    @pageActions = {}
    @tabs = {}

    @gifters = (criteria, callback) ->
      if typeof criteria is 'function'
        callback = criteria
        criteria = {}

      criteria['toAccount'] = self.id
      (new Gifters()).fetch(conditions: criteria, success: callback)

    @gifters['add'] = (gifterId, attrs, callback) ->
      if typeof attrs is 'function'
        [attrs, callback] = [{}, attrs]
      delete attrs['oid']
      delete attrs['toAccount']

      defaultFn = ->
        # Initialize new gifters to active
        attrs.active = true unless gifter.get('active') is false
        gifter.save attrs, success: ->
          callback?(gifter)

      gifter = new Gifter(oid: gifterId, toAccount: self.id)
      gifter.fetch success: defaultFn, error: defaultFn

    @gifters['sentGift'] = (gifterId, callback) ->
      defaultFn = ->
        sentCount = (gifter.get('sentCount') || 0) + 1
        gifter.save {lastGift: new Date(), sentCount}, success: ->
          callback(gifter) if callback

      gifter = new Gifter(oid: gifterId, toAccount: self.id)
      gifter.fetch success: defaultFn, error: defaultFn

    @gifts = (criteria, callback) ->
      if typeof criteria is 'function'
        callback = criteria
        criteria = {}

      criteria['toAccount'] = self.id
      (new Gifts()).fetch(conditions: criteria, success: callback)

    for criteria in ['unclaimed', 'claimed', 'expired', 'error', 'stolen']
      do (criteria) ->
        self.gifts[criteria] = (query, callback) ->
          if typeof query is 'function'
            callback = query
            query = {}
          query['status'] = criteria
          self.gifts(query, callback)

        self.gifts[criteria]['add'] = (attrs, callback) ->
          if typeof attrs is 'string'
            token = attrs
            attrs = {status: criteria}
          else
            token = attrs.token
            attrs.status = criteria
            delete attrs.token

          defaultFn = ->
            if criteria isnt 'unclaimed'
              attrs['claimTries'] = (gift.get('claimTries') || 0) + 1

            gift.save attrs, success: ->
              # Take care of possible automated claimer
              self.claimFinished() if self.giftClaimer && criteria isnt 'unclaimed'

              for tabId, tab of self.tabs['GiftListener'] || []
                tab.updateGift(token, criteria)

              callback?(gift)

          gift = new Gift({token, toAccount: self.id})
          gift.fetch success: defaultFn, error: defaultFn

  claimFinished: ->
    # Get a single unclaimed gift
    @gifts.unclaimed (gifts) =>
      gifts.comparator = (gift) -> gift.get('createdAt')
      # If there was no gift found look for gifts that had
      # errors when trying to claim and pick any that have
      # not been tried 5 times yet and mark them as unclaimed
      # again. The first one found kicks off the claim machine
      # on success and ends it all on error
      if not (gift = gifts.sort().at(gifts.length - 1))
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

  sendGifts: (sentGifts = 0, totalGifters, callback, sender) ->
    return unless picker = @tabs['ContactPicker']?[sender.tab.id]

    pbar = @tabs['ProgressBar']?[sender.tab.id] || {showProgress: (_, cb) -> cb?() }
    dal = @tabs['DAL']?[sender.tab.id] || {continueSendingGifts: (->), doneSendingGifts: ->}
    gifters = @gifters

    picker.waitToAppear ->
      gifters (all) ->
        all = (gifter.get('oid') for gifter in all.models when gifter.isGiftable())
        totalGifters ||= all.length
        lot = all[0...50]

        if totalGifters is 0
          progress = 50
        else
          progress = (sentGifts + (lot.length / 4.0)) / totalGifters * 100.0

        pbar.showProgress progress
        picker.selectUsers lot, (selected) ->
          if selected.length > 0
            pbar.showProgress (sentGifts + (lot.length * 3.0 / 4.0)) / totalGifters * 100.0
            picker.sendGift ->
              gifters.sentGift(oid) for oid in selected
              if all.length > 50
                dal.continueSendingGifts(sentGifts + lot.length, totalGifters)
              else
                pbar.showProgress 100, ->
                  dal.doneSendingGifts()
          else
            pbar.showProgress(100, -> picker.cancel())

  registerTab: (name, callback, sender) ->
    collection = @tabs[name] ||= {}
    return if collection[sender.tab.id]

    switch name
      when 'ContactPicker'
        # Only allow the contact picker, which attaches itself to a generic
        # google contact picker to only register itself when coming from a tab
        # that has the DAL game loaded in it
        return unless /plus\.google\.com\/(u\/\d+\/)?games\/867517237916/.test(sender.tab.url)

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

            chrome.extension.sendRequest({method: "#{prefix}#{method}", args}, callback)

        walkMethodTree(anchor[method], root[method], "#{prefix}#{method}.")

    walkMethodTree(Account, new Account())
