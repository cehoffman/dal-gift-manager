# setInterval( ->
#   previousTracker.splice(0, 0, window.location.pathname);
#   previousTracker.length = 2

#   if previousTracker[0] isnt previousTracker[1]
#     previous = previousTracker[1]

#     # Simulate that this is a fresh page load
#     allGifts = {}
#     lastGiftRound.length = 0

#     if matchPath(window.location.pathname)
#       # Reload the page is we hit another page that we
#       # are supposed to be active on, there is a weird
#       # problem with a stale dom in that situation
#       if matchPath(previous)
#         window.location = window.location


#       activateWaiter = setTimeout( ->
#         findGifts()
#         if moreButton()
#           moreButton().addEventListener 'click', (e) ->
#             setTimeout(findGifts, 1000)

#         Account.addTab()
#       , 1000)
#     else if activateWaiter
#       Account.removeTab()
#       clearTimeout(activateWaiter)
#       activateWaiter = null
# , 100)

class GPlus
  constructor: ->
    @content = document.getElementById('content')
    @gifts = {}
    @maxRounds = 5

  listenForGifts: ->
    @content.addEventListener 'DOMNodeInserted', @domAdded.bind(@)
    @content.addEventListener 'DOMNodeRemoved', @domRemoved.bind(@)
    chrome.extension.onRequest.addListener (request, sender, callback) =>
      @[request.method]?([request.args..., callback]...)

  giftToken: giftHash

  updateGift: (token, status, callback) ->
    for item in @gifts[token] || []
      @render(item, status)

  fetchAllGifts: (callback, prevGiftCount, prevUnclaimedCount, roundCount = 0) ->
    if roundCount is 0
      prevUnclaimedCount = @numUnclaimedGiftsOnPage()
      prevGiftCount = @numGiftsOnPage()

      # Don't bother fetching more gifts if all displayed gifts are claimed
      return if prevUnclaimedCount is 0 and prevGiftCount > 0
      Account.claimStart()

    moreButton = document.getElementsByClassName('a-j hk ir')[0]

    Event(moreButton).click()

    moreTimer = setInterval =>
      if moreButton.offsetWidth isnt 0
        clearInterval(moreTimer)

        unclaimedCount = @numUnclaimedGiftsOnPage()
        giftCount = @numGiftsOnPage()

        if (unclaimedCount isnt prevUnclaimedCount || giftCount is prevGiftCount) && roundCount < @maxRounds
          @fetchAllGifts(callback, giftCount, unclaimedCount, roundCount + 1)

    , 100

  numGiftsOnPage: ->
    count = 0
    count += list.length for token, list of @gifts
    count

  numUnclaimedGiftsOnPage: ->
    count = 0
    for token, list of @gifts
      for item in list
        status = item.getAttribute('data-claim-status')
        if status is 'unclaimed' || status is 'error'
          count++
          break
    count


  render: (node, status) ->
    node.setAttribute('data-claim-status', status)

  eachGift: (domNode, callback) ->
    if domNode.nodeName isnt '#text'
      for item in domNode.getElementsByClassName('c-i-j-ua')
        if item.childNodes[item.childNodes.length - 1].nodeName is '#text'
          token = @giftToken(item.href)
          callback(item, token) if token

  domAdded: (event) ->
    @eachGift event.target, (item, token) =>
      list = @gifts[token] ||= []
      if item not in list
        list.push item

      Account.gifts {token}, (gifts) =>
        console.log(token, gifts, gifts[0])
        if not gifts[0]
          Account.gifts.unclaimed.add(token)
        else
          @render(item, gifts[0].status)

    @activate() if not @active && @numGiftsOnPage() > 0

  domRemoved: (event) ->
    @eachGift event.target, (item, token) =>
      list = @gifts[token] ||= []
      if (i = list.indexOf(item)) >= 0
        list[i..i] = []
        delete @gifts[token] if list.length is 0

    if @active
      if @numGiftsOnPage() > 0
        @activate()
      else
        @deactivate()

  activate: ->
    @active = true
    Account.addTab()

  deactivate: ->
    @active = false
    Account.removeTab()

(new GPlus()).listenForGifts()
