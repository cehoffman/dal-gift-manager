chrome.extension.onRequest.addListener (request, sender, callback) ->
  next = Account.find(sender.tab.id)
  root = null
  for part in request.method.split('.')
    [root, next] = [next, next[part]]
  args = [request.args..., callback, sender]
  next.apply(root, args)

chrome.pageAction.onClicked.addListener (tab) ->
  account = Account.find(tab.id)
  account.tabs['GPlus']?[tab.id]?.fetchAllGifts()
  account.tabs['CircleSelection']?[tab.id]?.getUsers (users) ->
    if users.length is 0
      account.gifters (all) ->
        all = (gifter.get('oid') for gifter in all.models)
        account.tabs['CircleSelection']?[tab.id]?.selectUsers(all)
    else
      account.gifters (all) ->
        oids = {}
        oids[user.oid] = true for user in users

        for gifter in all.models when not oids[gifter.get('oid')]
          gifter.save({active: false})

        for user in users
          account.gifters.add(user.oid, user)

chrome.tabs.onRemoved.addListener Account.remove
