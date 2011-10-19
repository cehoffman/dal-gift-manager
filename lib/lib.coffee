Event = (element) ->
  dispatch = (type, subtype, args...) ->
    event = document.createEvents(type)
    event.initEvent(subtype, args...)
    element.dispatch(event)
  mousedown: ->
    dispatch('MouseEvents', 'mousedown', true, true)
    @
  mouseup: ->
    dispatch('MouseEvents', 'mouseup', true, true)
    @
  click: ->
    dispatch('MouseEvents', 'click', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
    @

app = new App

class Account
  accounts = {}
  @find: (id) ->
    return accounts[id] if accounts[id]

    account = JSON.parse(localStorage.getItem(id) || '{}')
    accounts[id] = new @(account)

  constructor: (data = {}) ->
    @gifters = new Gifters(data['gifters'] || [])
    @gifts = new Gifts(data['gifts'] || [])

  claimGift: (token) ->
    @gifts.push @gifts.find(token) || new Gift({token, status: 'claimed'})

  isClaimed: (token) ->
    @gifts.find(token)?.status is 'claimed'

  isUnclaimed: (token) -> not @isClaimed()

class Gifts extends Array
  constructor: (gifts) ->
    super()

    for gift in gifts
      @push(new Gift(gift))

  find: (token) ->
    return gift for gift in @ when gift.token is token

  unclaimed: () ->
    gift for gift in @ when gift.status is 'unclaimed'

  claimed: () ->
    gift for gift in @ when gift.status is 'claimed'

class Gift
  constructor: ({@token, @status, @createdAt, @updatedAt}) ->
    @status ||= 'unclaimed'
    @createdAt ||= new Date()
    @updatedAt ||= new Date()

chrome.extension.onRequest.addListener((request, sender, callback) ->
  App[request.method]?([Account.find(request.account_id), request.args..., sender, callback]...)
)
