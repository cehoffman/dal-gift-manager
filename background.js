var unclaimed = [], giftClaimer, pendingClaim = {}, activeTabs = {};

function claimGifts() {
  if (unclaimed.length == 0) {
    chrome.tabs.remove(giftClaimer.id)
    return giftClaimer = void(0);
  }

  var gift = unclaimed.shift(), hash = gift.pop();
  gift = gift.shift();

  if (!localStorage[hash]) {
    if (!giftClaimer) {
      giftClaimer = true;
      chrome.tabs.create({url: gift, selected: false}, function(tab) { giftClaimer = tab; })
    } else {
      chrome.tabs.update(giftClaimer.id, {url: gift})
    }


    // setTimeout(claimGifts, 12000);
  } else {
    claimGifts();
  }
}

chrome.extension.onRequest.addListener(function(request, sender, sendResponse) {
  if (request.checkClaim) {
    sendResponse(localStorage[giftHash(request.checkClaim)]);
  } else if (request.markClaim || request.claimExpired) {
    var hash = request.markClaim || request.claimExpired;
    localStorage[hash] = new Date();
    delete pendingClaim[hash];

    // notify tabs that this gift is claimed
    var msg = {markClaim: true, hash: hash},response = function(resp) {};
    for (var tabId in activeTabs) {
      chrome.tabs.sendRequest(+tabId, msg, response);
    }

    // If we are automating the claim process, continue onto next one
    if (giftClaimer) {
      claimGifts();
    }
  } else if (request.activate) {
    activeTabs[sender.tab.id] = true;
    chrome.pageAction.show(sender.tab.id);
  } else if (request.deactivate) {
    delete activeTabs[sender.tab.id];
    chrome.pageAction.hide(sender.tab.id);
  } else if (request.claimError) {
    var hash = btoa(JSON.stringify({page: 'acceptedGift', token: request.claimError}));
    unclaimed.push("https://plus.google.com/games/867517237916/params/" + encodeURIComponent(JSON.stringify({"encPrms": hash})) + "/source/3")
    if (giftClaimer) {
      claimGifts()
    }
  } else if (request.claimTimeout) {
    if (giftClaimer) {
      claimGifts();
    }
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
            unclaimed.push([msg.unclaimed, hash]);
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
