class Account
  accounts = {}
  @find: (id) ->
    accounts[id] ||= new @(id)

  @each: (callback) ->
    callback(account) for id, account of accounts

  constructor: (@id) ->
    @tabs = {}
    @gifts = (criteria, callback) ->
      if typeof criteria is 'function'
        callback = criteria
        criteria = {}

      criteria['toAccount'] = id
      (new Gifts()).fetch(conditions: criteria, success: callback)

    for criteria in ['unclaimed', 'claimed', 'error', 'stolen']
      do (criteria) =>
        @gifts[criteria] = (callback) =>
          @gifts(status: criteria, callback)

        @gifts[criteria]['add'] = (token, callback) =>
          defaultFn = =>
            console.log(arguments)
            gift.save {status: criteria}, success: =>
              for tabId, _ of @tabs
                chrome.tabs.sendRequest(+tabId, {method: 'updateGift', args: [token, criteria]})

          gift = new Gift({token, toAccount: id})
          gift.fetch success: defaultFn, error: defaultFn

        # @gifts[criteria]['contains'] = (token, callback) ->
        #   criteria = {token: token, toAccount: id}
        #   (new Gift(criteria)).fetch
        #     success: -> callback(true)
        #     error: -> callback(false)


  # receivedGifts: ->

  # gifts: (criteria, callback) ->
  #   if typeof criteria is 'function'
  #     callback = criteria
  #     criteria = {}

  #   criteria['toAccount'] = @id
  #   console.log(criteria)
  #   (new Gifts()).fetch(conditions: criteria, success: callback, error: callback)

  # for criteria in ['unclaimed', 'claimed', 'error']
  #   do (criteria) =>
  #     @::gifts[criteria] = (callback) ->
  #       @(status: criteria, callback)

  #     @::gifts[criteria]['add'] = (token, callback) ->
  #       gift = new Gift({token, toAccount: @id})
  #       gift.fetch
  #         success: ->
  #           gift.save({status: criteria}, success: callback)
  #         error: ->
  #           gift.save({status: criteria}, success: callback)
  # @::gifts.unclaimed = (callback) ->
  #   @(status: 'unclaimed', callback)

  # @::gifts.claimed = (callback) ->
  #   @(status: 'claimed', callback)

  # @::gifts.error = (callback) ->
  #   @(status: 'error', callback)

  # unclaimedGifts: (callback) ->
  #   (new Gifts()).fetch(conditions: {toAccount: @id, status: 'unclaimed'}, success: callback)

  # errorGifts: (callback) ->
  #   (new Gifts()).fetch(conditions: {toAccount: @id, status: 'error'}, success: callback)

  # hasClaimedGift: (id, callback) ->
  #   (new Gift({token: id, toAccount: @id})).fetch(success: (-> callback(true)), error: (-> callback(false)))

  # claimGift: (id, callback) ->
  #   gift = new Gift(token: id, toAccount: @id)
  #   gift.fetch
  #     success: ->
  #       gift.save({status: 'claimed'}, success: callback)
  #     error: ->
  #       gift.save({status: 'claimed'}, success: callback)

  # addGift: (id, callback) ->
  #   gift = new Gift(token: id, toAccount: @id)
  #   gift.fetch
  #     success: ->
  #       gift.touch(success: callback)
  #     error: ->
  #       gift.save({}, success: callback)

  addGiftFromFriend: (token, friendId, callback) ->
    @addGift(token, -> @addGifter(friendId, callback))

  addGifter: (id, callback) ->
    (new Gifter({toAccount: @id, gplusId: id})).fetch
      success: (model) ->
        model.touch(success: callback)
      error: (model) ->
        model.save({}, success: callback, error: callback)

  addTab: (callback, sender) ->
    (@activeTabs ||= {})[sender.tab.id] = true
    null

  removeTab: (callback, tabId) ->
    delete @activeTabs[sender.tab.id]
    null

if window.location.protocol isnt 'chrome-extension:'
  do ->
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
          console.log(user)
          if user.id
            alertIdReady(user.id)
          else if tries < 5
            setTimeout((-> google.plusone.api('/people/me', postId)), 100)

        google.plusone.api '/people/me', postId
    ).toString() + ')(this);')
    document.body.appendChild(idDiv)

    idDiv.addEventListener 'gplusid', ->
      Account.id = accountId = idDiv.getAttribute('oid')
      console.log('Got id of ' + Account.id)
      for item in queue
        item[0].accountId = accountId
        chrome.extension.sendRequest(item...)
      document.body.removeChild(idDiv)

    Event(idDiv).click()

    nullFn = ->

    walkMethodTree = (anchor, root, prefix = '') ->
      for method of root
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
              catch e
                console.log(signature)
                console.log(e)
            else
              queue.push signature

        walkMethodTree(anchor[method], root[method], "#{prefix}#{method}.")

    walkMethodTree(Account, new Account())

