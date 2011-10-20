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
          if token = @giftToken(item.href)
            if /\/(u\/\d+\/)?games\/notifications/.test(window.location.pathname)
              entry = item.parentElement
              entry = entry.parentElement until entry.className is 'PA' || entry is document.body
              giftFrom = entry.getElementsByClassName('jda')[0]?.childNodes[0]
              giftFrom = giftFrom?.href?.match(/(\d+)$/)?[1]
            else
              giftFrom = undefined
            callback(item, token, giftFrom)

  domAdded: (event) ->
    @eachGift event.target, (item, token, from) =>
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
