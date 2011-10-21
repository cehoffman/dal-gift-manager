class CircleSelection extends ContactScroller
  setup: ->
    @content = document.getElementById('content')
    @listenForCircles()

  listenForCircles: ->
    isCirclePage = (dom) ->
      dom.nodeName isnt '#text' &&
        (/(\s|^)oz-sg-contacts(\s|$)/.test(dom.className) ||
        dom.getElementsByClassName('oz-sg-contacts').length > 0)

    @content.addEventListener 'DOMNodeInserted', (event) =>
      @register() if @active || isCirclePage(event.target)
    @content.addEventListener 'DOMNodeRemoved', (event) =>
      @unregister() if isCirclePage(event.target)

  @api
    getUsers: (callback) ->
      selected = {}
      getSelected = ->
        for el in [document.getElementsByClassName('vi-X')...]
          oid = el.getAttribute('oid')
          name = el.getElementsByClassName('tD bv')?[0]?.innerText
          selected[account] = {oid, name} if oid

      @scroll
        setup: getSelected
        step: getSelected
        teardown: -> callback(data for oid, data of selected)

  register: ->
    @active = true
    Account.showPageAction('circlePicker')
    super

  unregister: ->
    @active = false
    Account.hidePageAction('circlePicker')
    super

CircleSelection.enable()
