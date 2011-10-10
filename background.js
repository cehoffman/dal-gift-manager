var unclaimed = [], giftClaimer, pendingClaim = {}, activeTabs = {};

function giftHash(url) {
  var hash = url.match(/%22%3A%22(.*)%22%7D/);
  if (hash) {
    return hash[1];
  }
}

function notifyClaimed(hash) {
  var msg = {markClaim: true, hash: hash},response = function(resp) {};
  for (var tabId in activeTabs) {
    chrome.tabs.sendRequest(+tabId, msg, response);
  }
}

function claimGifts() {
  if (unclaimed.length == 0) {
    chrome.tabs.remove(giftClaimer.id)
    return giftClaimer = void(0);
  }

  var tabId = unclaimed.pop(), hash = unclaimed.pop(), gift = unclaimed.pop();

  if (!localStorage[hash]) {
    localStorage[hash] = new Date();
    delete pendingClaim[hash];
    notifyClaimed(hash);

    if (!giftClaimer) {
      giftClaimer = true;
      chrome.tabs.create({url: gift, selected: false}, function(tab) { giftClaimer = tab; })
    } else {
      chrome.tabs.update(giftClaimer.id, {url: gift})
    }


    setTimeout(claimGifts, 12000);
  } else {
    claimGifts();
  }
}

chrome.extension.onRequest.addListener(function(request, sender, sendResponse) {
  if (request.checkClaim) {
    sendResponse(localStorage[giftHash(request.checkClaim)]);
  } else if (request.markClaim && !localStorage[request.markClaim]) {
    localStorage[request.markClaim] = new Date();
    notifyClaimed(request.markClaim);
  } else if (request.activate) {
    activeTabs[sender.tab.id] = true;
    chrome.pageAction.show(sender.tab.id);
  } else if (request.deactivate) {
    delete activeTabs[sender.tab.id];
    chrome.pageAction.hide(sender.tab.id);
  }
});

chrome.pageAction.onClicked.addListener(function(tab) {
  var port = chrome.tabs.connect(tab.id, {}), hash, noGiftsInLot = true,
  unclaimedGift = false, roundCount = 1, maxRounds = 5, cleanup = function() {
    try {
      port.disconnect();
    } catch(e) { }

    chrome.pageAction.show(tab.id);

    // Remove any gifts from tracking that haven't been touched in 7 days
    var cutoff = new Date() - 1000 * 60 * 60 * 24 * 7
    for (var key in localStorage) {
      if (Object.prototype.hasOwnProperty.call(localStorage, key)) {
        if (new Date(localStorage[key]) < cutoff) {
          delete localStorage[key];
        }
      }
    }
  };

  chrome.pageAction.hide(tab.id);

  port.onMessage.addListener(function(msg) {
    if (msg.unclaimed) {
      hash = giftHash(msg.unclaimed);
      if (hash) {
        noGiftsInLot = false;

        if (!localStorage[hash]) {
          if (!pendingClaim[hash]) {
            pendingClaim[hash] = true;
            unclaimedGift = true;
            unclaimed.push([msg.unclaimed, hash, tab.id]);
            if (!giftClaimer) {
              claimGifts()
            }
          }
        } else {
          // Update the access time so it doesn't get culled too early
          localStorage[hash] = new Date();
        }
      }
    }

    if (msg.finishedRound) {
      if ((unclaimedGift || noGiftsInLot) && roundCount < maxRounds) {
        noGiftsInLot = true;
        unclaimedGift = false;
        roundCount++;
        port.postMessage({findGifts: true});
      } else {
        cleanup();
      }
    }

    if (msg.finished) {
      cleanup();
    }
  });

  port.onDisconnect.addListener(cleanup)
});
