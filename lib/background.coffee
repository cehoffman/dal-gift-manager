chrome.extension.onRequest.addListener (request, sender, callback) ->
  if request.accountId
    args = [request.args..., callback, sender]
    Account.find(request.accountId)[request.method]?(args...)
