chrome.extension.onRequest.addListener (request, sender, callback) ->
  if request.accountId
    next = Account.find(request.accountId)
    root = null
    for part in request.method.split('.')
      tmp = next
      next = next[part]
      root = tmp
    args = [request.args..., callback, sender]
    next.apply(root, args)

chrome.pageAction.onClicked.addListener (tab) ->
  Account.each (account) ->
    account.tabs['GPlus']?[tab.id]?.fetchAllGifts()

chrome.tabs.onRemoved.addListener (tabId) ->
  Account.each (account) ->
    account.claimStopped(tabId)
