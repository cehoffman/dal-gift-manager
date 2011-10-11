var activateWaiter, previous, previousTracker = [],
    allGifts = {}, lastGiftRound = [], originalUnload = window.onbeforeunload;

window.onbeforeunload = function() {
  chrome.extension.sendRequest({deactivate: true});
  if (originalUnload) {
    originalUnload.call(this);
  }
}

function matchPath(path) {
  return /^\/(u\/\d+\/)?notifications\/(all|games)/.test(path) ||
         /^\/(u\/\d+\/)?games\/notifications/.test(path)
}

function giftHash(url) {
  var hash = url.match(/%22%3A%22(.*)%22%7D/);
  if (hash) {
    try {
      hash = JSON.parse(atob(hash[1]));
    } catch (e) {}
    if (hash['page'] == 'acceptedGift' ) {
      return hash['token'];
    }
  }
}

function isGiftPath(url) {
  if (/\/games\/867517237916\//.test(url)) {
    return giftHash(url)
  }
}

// Track our history so when we move between two pages we modify
// we can reload the page because of funkyness in the dom manip
// get a stale copy
setInterval(function() {
  previousTracker.splice(0, 0, window.location.pathname);
  previousTracker.length = 2;
  if (previousTracker[0] !== previousTracker[1]) {
    previous = previousTracker[1];

    // Simulate that this is a fresh page load
    allGifts = {}
    lastGiftRound.length = 0;

    if (matchPath(window.location.pathname)) {
      // Reload the page is we hit another page that we
      // are supposed to be active on, there is a weird
      // problem with a stale dom in that situation
      if (matchPath(previous)) {
        window.location = window.location;
      }

      activateWaiter = setTimeout(function() {
        findGifts()
        if (moreButton()) {
          moreButton().addEventListener('click', function(e) {
            setTimeout(findGifts, 1000);
          });
        }
        chrome.extension.sendRequest({activate: true}, function(response) {});
      }, 1000);
    } else if (activateWaiter) {
      chrome.extension.sendRequest({deactivate: true}, function(response) {});
      clearTimeout(activateWaiter);
      activateWaiter = void(0);
    }

  }
}, 100);


function findGifts() {
  var hash, items = window.document.getElementsByClassName('c-i-j-ua');
  lastGiftRound.length = 0;

  for (var i = 0, len = items.length; i < len ; i++) {
    el = items[i];
    if (el.text === 'Play now' && isGiftPath(el.href)) {
      var hash = giftHash(el.href);
      if (!allGifts[hash]) {
        allGifts[hash] = el;
        lastGiftRound.push(el);
        !function(gift) {
          chrome.extension.sendRequest({checkClaim: gift.href}, function(claimed) {
            decorateGift(gift, claimed);
          });
        }(el);
      }
    }
  }
}

function decorateGift(gift, claimed) {
  var image
  if (gift.childNodes[0].nodeName === 'IMG') {
    image = gift.childNodes[0];
  } else {
    image = document.createElement('img');
    image.style.verticalAlign = "bottom";
    image.style.paddingRight = "3px";
    gift.insertBefore(image, gift.childNodes[0]);
  }
  image.style.paddingBottom = claimed ? "1px" : "0px";
  image.src = chrome.extension.getURL(claimed ? 'opened.png' : 'icon16.png');
}

function moreButton() {
  var el;

  return (function () {
    if (el) {
      return el
    }

    var results = [], els = document.getElementsByClassName('a-j hk ir');
    for (var i = els.length - 1; i >= 0; i--) {
      if (els[i].text === 'More' || els[i].innerText === 'More') {
        return el = els[i];
      }
    }
  })()
}

chrome.extension.onRequest.addListener(function(request, sender, sendResponse) {
  if (typeof request.markClaim !== "undefined" && request.markClaim != null) {
    if (allGifts[request.hash]) {
      decorateGift(allGifts[request.hash], request.markClaim);
    }
  }
});

chrome.extension.onConnect.addListener(function(port) {
  var getMore = function() {
    var el = moreButton(), event;

    if (el && el.offsetWidth !== 0 && el.offsetHeight !== 0) {
      event = document.createEvent("MouseEvents");
      event.initEvent('click', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
      el.dispatchEvent(event);
      return true;
    }
  },
  postLastGiftRound = function() {
    for (var i = 0, len = lastGiftRound.length; i < len; i++) {
      port.postMessage({unclaimed: lastGiftRound[i].href});
    }
    port.postMessage({finishedRound: true});
  }

  port.onMessage.addListener(function(msg) {
    if (msg.findGifts) {
      if (getMore()) {
        setTimeout(postLastGiftRound, 1100);
      } else {
        port.postMessage({finished: true});
      }
    }
  });

  port.onDisconnect.addListener(function() { });

  allGifts = {};
  findGifts();
  postLastGiftRound();
});
