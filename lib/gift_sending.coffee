waitingToDetect = false
waitToScroll = ->
  if window.innerWidth is 0
    waitingToDetect = setTimeout(waitToScroll, 100)
  else
    waitingToDetect = false
    chrome.extension.sendRequest getGifters: true, (gifters) ->
      scroller = document.getElementsByClassName('NP')[0]
      oldScroll = scroller.onscroll
      scroller.onscroll = ->
        pickVisibleGifters(gifters)
        oldScroll.apply(window, [arguments...]) if oldScroll
      pickVisibleGifters(gifters)

      scrollContacts()

scrollTimer = null
scrollContacts = ->
  scroller = document.getElementsByClassName('NP')[0]
  curScroll = scroller.scrollTop

  scroller.scrollTop += 200
  if scroller.scrollTop is curScroll
    setTimeout( ->
      chrome.extension.sendRequest availableGifters: true, (gifters) ->
        for gifter in gifters when gifter in selected
          console.log("Not selecting https://plus.google.com/#{gifters[i]}/posts")
    , 300)
  else
    scrollTimer = setTimeout(scrollContacts, 100)

selected = []
pickVisibleGifters = ->
  for el in document.getElementsByClassName('cl')
    if selected.length < 50
      oid = el.getAttribute('oid')
      if el and oid in gifters and oid not in selected
        selected.push(oid)
        Event(el).mousedown().mouseup()
    else
      clearTimeout(scrollTimer) if scrollTimer

      preview = document.getElementsByClassName('a-wc-na')
      Event(preview[0]).click()

      setTimeout( ->
        preview = document.getElementsByClassName('a-wc-na')
        Event(preview[0]).click()

        if selected.length < gifters.length
          chrome.extension.sendRequest(continueGifting: true)
      , 100)

      break

document.body.addEventListener 'DOMNodeInserted', (event) ->
  chrome.extension.sendRequest isSendingGift: true, (isSendingGift) ->
    if isSendingGift && !waitingToDetect && window.innerWidth is 0
      scrollTimer = undefined
      # selected.length = 0
      waitToScroll()
