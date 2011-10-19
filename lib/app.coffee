App =
  availableToGift: (account, sender, callback) ->
    callback(JSON.parse(localStorage.getItem('gifters') || 'null'))

  addGiftFromGifter: (account, gift_id, gifter_id) ->
    gifter = account.gifters.find(gifter_id) || new Gifter({id: gifter_id})
    gifter.addGift()
    
  addGifter: (account, gifter_id, sender) ->
    gifter ||= account.gifters.find(gifter_id)
    account.gifters.push(new Gifter({id: gifter_id}))

  claimGift: (account, token, sender, callback) ->
    account.claimGift(token)

if window.location.protocol isnt 'chrome-extension:'
  for own method of App
    do (method) ->
      App[method] = (args...) ->
        if typeof args[args.length - 1] is 'function'
          callback = args[args.length - 1]
          args = args[0...-1]
        else
          callback = null

        # Add the user account identifier from G+
        chrome.extension.sendRequest({method, args, account_id: OZ_initData[2][0]}, callback)

