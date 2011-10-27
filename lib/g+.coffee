class GPlus extends TabApi
  sendId: ->
    idDiv = document.createElement('div')
    idDiv.style.display = 'none'
    idDiv.setAttribute('onclick', '(' + ((el) ->
      alertIdReady = (id) ->
        el.setAttribute('oid', id)
        event = document.createEvent('Events')
        event.initEvent('user:gplusid', true, true)
        el.dispatchEvent(event)

      if OZ_initData?[2]?[0]?
        alertIdReady(OZ_initData[2][0])
    ).toString() + ')(this);')

    document.body.appendChild(idDiv)

    idDiv.addEventListener 'user:gplusid', =>
      Account.setId(idDiv.getAttribute('oid'))
      document.body.removeChild(idDiv)

    Event(idDiv).click()

  setup: ->
    @sendId()
    @register()

  @api
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
    count++ for item in [document.getElementsByTagName('*')...] when item.getAttribute('data-claim-status')
    count

  numUnclaimedGiftsOnPage: ->
    count = 0
    count++ for item in [document.getElementsByTagName('*')...] when item.getAttribute('data-claim-status') is 'unclaimed'
    count

GPlus.enable()

class ProgressBar extends TabApi
  setup: ->
    @container = document.createElement('div')
    @container.id = 'progress-bar'
    @container.style.display = 'none'
    @container.innerHTML = """
    <div class="ui-progress-bar">
      <div class="ui-progress">
        <span class="ui-label">Processing...<strong>79%</strong></span>
      </div>
    </div>
    """
    document.body.appendChild(@container)
    @bar = @container.getElementsByClassName('ui-progress')[0]
    @label = @bar.getElementsByTagName('span')[0]
    @percent = @label.getElementsByTagName('strong')[0]
    @movements = []

    @register()

  show: ->
    @container.style.opacity = 0
    @container.style.display = 'block'
    @label.firstChild.nodeValue = 'Processing...'
    @animate @container, 'opacity', 1, 1000

  @api
    showProgress: (percent, callbacks...) ->
      if @animating
        if @movements.lengths > 0
          if @movements[@movements.length - 1][1]
            if @movements[@movements.length - 1][0] is percent
              callbacks = [@movements[@movements.length - 1][1..-1]..., callbacks...]
              @movements.pop()
          else
            @movement.pop()
        @movements.push([percent, callbacks...])
      else
        duration = 2000
        if @isHidden(@container)
          @show()
          @bar.style.width = '1%'
        else
          start = +@container.style.width.match(/(\d+)/)?[1]
          if (diff = Math.abs(start - percent)) < 40
            duration = diff / 40 * duration


        @animating = true
        @animate @bar, 'width', "#{percent}%", duration,
          step: (progress, timeUsed) =>
            if Math.ceil(progress) < 20
              if @isVisible(@label)
                @label.style.display = 'none'
            else
              if @isHidden(@label)
                @label.style.opacity = '0'
                @label.style.display = 'block'
                @animate @label, 'opacity', 1.0, 1000

            if Math.abs(progress - 100) < 5e-10
              @percent.innerText = ''
              @label.firstChild.nodeValue = 'Done'
              @hide()
            else
              @percent.innerText = "#{Math.ceil(progress)}%"
          complete: =>
            @animating = false
            callback?() for callback in callbacks
            @showProgress @movements.shift()... if @movements.length > 0

    hide: ->
      @animate @container, 'opacity', 0, 1000, complete: => @container.style.display = 'none'


  isHidden: (item) ->
    (item.offsetWidth is item.offsetHeight is 0) || item.style.display is 'none'

  isVisible: (item) ->
    !@isHidden(item)

  animate: (item, property, to, duration, callbacks) ->
    easing = (start, current, target) ->
      ((-Math.cos(current / duration * Math.PI) / 2) + 0.5) * (target - start) + start

    step = callbacks?.step

    startValue = +(item.style[property].match(/(\d+)/)?[1] || 0)
    if typeof to is 'string' && /%$/.test(to)
      isPercent = '%'
      to = to.match(/(\d+)/)[1]
    else
      isPercent = ''

    timeUsed = -40
    runner = =>
      timeUsed += 40
      if timeUsed > duration
        clearInterval(timer)
        item.style[property] = "#{position}#{isPercent}"
        callbacks?.complete?()
      else
        position = easing(startValue, timeUsed, to)
        item.style[property] = "#{position}#{isPercent}"
        step(position, timeUsed) if step
    runner()
    timer = setInterval runner, 40 if timeUsed < duration

ProgressBar.enable()
