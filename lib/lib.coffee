giftHash = (url) ->
  if hash = url.match(/%22%3A%22(.*)%22%7D/)
    try
      hash = JSON.parse(atob(hash[1]))
      if hash['page'] is 'acceptedGift'
        hash['token']
    catch e
      console.log(e)

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
