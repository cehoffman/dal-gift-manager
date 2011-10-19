class Account
  accounts = {}
  @find: (id) ->
    accounts[id] ||= new @(id)

  constructor: (@id) ->

  # receivedGifts: ->

  gifts: (callback) ->
    (new Gifts()).fetch(conditions: {toAccount: @id}, success: callback, error: callback)

  unclaimedGifts: (callback) ->
    (new Gifts()).fetch(conditions: {toAccount: @id, status: 'unclaimed'}, success: callback)

  errorGifts: (callback) ->
    (new Gifts()).fetch(conditions: {toAccount: @id, status: 'error'}, success: callback)

  hasClaimedGift: (id, callback) ->
    (new Gift({token: id, toAccount: @id})).fetch(success: (-> callback(true)), error: (-> callback(false)))

  claimGift: (id, callback) ->
    gift = new Gift(token: id, toAccount: @id)
    gift.fetch
      success: ->
        gift.save({status: 'claimed'}, success: callback)
      error: ->
        gift.save({status: 'claimed'}, success: callback)

  addGift: (id, callback) ->
    gift = new Gift(token: id, toAccount: @id)
    gift.fetch
      success: ->
        gift.touch(success: callback)
      error: ->
        gift.save({}, success: callback)

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

    Event(idDiv).click()

    idDiv.addEventListener 'gplusid', ->
      Account.id = accountId = idDiv.getAttribute('oid')
      document.body.removeChild(idDiv)

    for own method of Account::
      do (method) ->
        Account[method] = (args...) ->
          if typeof args[args.length - 1] is 'function'
            callback = args[args.length - 1]
            args = args[0...-1]
          else
            callback = null

          # Add the user account identifier from G+
          if accountId
            chrome.extension.sendRequest({method, args, accountId}, callback)
          else
            console.log('Account id is missing, can\'t communicate to bg tab')

