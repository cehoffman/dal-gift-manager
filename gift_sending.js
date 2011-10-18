var waitingToDetect, waitToScroll = function() {
  if (window.innerWidth === 0) {
    waitingToDetect = setTimeout(waitToScroll, 100);
  } else {
    waitingToDetect = false;
    chrome.extension.sendRequest({getGifters: true}, function(gifters) {
      var scroller = document.getElementsByClassName('NP')[0],
          oldScroll = scroller.onscroll;
      scroller.onscroll = function() {
        pickVisibleGifters(gifters);
        if(oldScroll) {
          oldScroll.apply(window, Array.prototype.slice.call(argument, 0));
        }
      }
      pickVisibleGifters(gifters);

      scrollDiv()
    });
  }
}, scrollDiv = function() {
  var scroller = document.getElementsByClassName('NP')[0], curScroll = scroller.scrollTop;

  scroller.scrollTop += 200;
  if (scroller.scrollTop === curScroll) {
    setTimeout(function () {
      chrome.extension.sendRequest({getGifters: true}, function(gifters) {
        for (var i = 0, len = gifters.length; i < len; i++) {
          if (selected.indexOf(gifters[i]) < 0) {
            console.log('Not selecting https://plus.google.com/' + gifters[i] + '/posts');
          }
        }
      })
    }, 300);
  } else {
    setTimeout(scrollDiv, 100);
  }
}, pickVisibleGifters = function(gifters) {
  var possible = document.getElementsByClassName('cl');
  for (var i = 0, len = possible.length; i < len; i++) {
    var el = possible[i];
    if (el && gifters.indexOf(el.getAttribute('oid')) >= 0) {
      selected.push(el.getAttribute('oid'));
      var event = document.createEvent("MouseEvents");
      event.initEvent('mousedown', true, true);
      el.dispatchEvent(event);

      event = document.createEvent('MouseEvents');
      event.initEvent('mouseup', true, true);
      el.dispatchEvent(event);
    }
  }
}, selected = [];

document.getElementsByTagName('body')[0].addEventListener('DOMNodeInserted', function(event) {
  if (!waitingToDetect && window.innerWidth === 0) { 
    waitToScroll()
  }
});
