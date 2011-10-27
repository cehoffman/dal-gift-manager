class GiftListener extends TabApi
  setup: ->
    @content = document.body
    @gifts = {}
    @maxRounds = 5
    @listenForGifts()

  @api
    updateGift: (token, status, callback) ->
      for item in @gifts[token] || []
        @render(item, status)

  numGiftsOnPage: ->
    count = 0
    count += list.length for token, list of @gifts
    count

  numUnclaimedGiftsOnPage: ->
    count = 0
    for token, list of @gifts
      for item in list
        status = item.getAttribute('data-claim-status')
        if status is 'unclaimed'
          count++
          break
    count

  giftToken: giftHash

  render: (node, status) ->
    node.setAttribute('data-claim-status', status)
    if not @active && status is 'unclaimed'
      @register()
    else if @numUnclaimedGiftsOnPage() is 0
      @unregister()

  eachGift: (domNode, callback) ->
    if domNode.nodeName isnt '#text'
      for item in [domNode.getElementsByClassName('c-i-j-ua')...]
        if item.childNodes[item.childNodes.length - 1].nodeName is '#text'
          if token = @giftToken(item.href)
            if /\/(u\/\d+\/)?games\/notifications/.test(window.location.pathname)
              entry = item.parentElement
              entry = entry.parentElement until entry.className is 'V3 Zn' || entry is document.body
              giftFrom = entry.getElementsByClassName('jda')[0]?.childNodes[0]
              giftFrom = giftFrom?.href?.match(/(\d+)$/)?[1]
            else
              giftFrom = undefined
            callback(item, token, giftFrom)

  listenForGifts: ->
    @content.addEventListener 'DOMNodeInserted', @domAdded.bind(@)
    @content.addEventListener 'DOMNodeRemoved', @domRemoved.bind(@)

  domAdded: (event) ->
    @eachGift event.target, (item, token, from) =>
      list = @gifts[token] ||= []
      if item not in list
        list.push item

      Account.gifts {token}, (gifts) =>
        if not gifts[0]
          Account.gifts.unclaimed.add {token, href: item.href},(gift) =>
            @render(item, gift.status)
        else
          @render(item, gifts[0].status)

      if from
        Account.gifters {oid: from}, (gifters) =>
          if not gifters[0]
            Account.gifters.add(from)

  domRemoved: (event) ->
    @eachGift event.target, (item, token) =>
      list = @gifts[token] ||= []
      if (i = list.indexOf(item)) >= 0
        list[i..i] = []
        delete @gifts[token] if list.length is 0

    if @active
      if @numUnclaimedGiftsOnPage() > 0
        @register()
      else
        @unregister()

  register: ->
    @active = true
    try Account.showPageAction('giftClaimer') if top is window
    super

  unregister: ->
    @active = false
    try Account.hidePageAction('giftClaimer') if top is window
    super

GiftListener.enable()
