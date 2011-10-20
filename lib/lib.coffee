giftHash = (url) ->
  token = url.match(/%22%3A%22(.*)%22%7D/)
  if token
    try
      token = JSON.parse(atob(token[1]))
    catch e
      try
        token = JSON.parse(atob(token[1][0...-1]))
      catch e

    token.token if token.page is 'acceptedGift'

Event = (element) ->
  dispatch = (type, subtype, args...) ->
    event = document.createEvent(type)
    event.initEvent(subtype, args...)
    element.dispatchEvent(event)
  mousedown: ->
    dispatch('MouseEvents', 'mousedown', true, true)
    @
  mouseup: ->
    dispatch('MouseEvents', 'mouseup', true, true)
    @
  click: ->
    dispatch('MouseEvents', 'click', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
    @
