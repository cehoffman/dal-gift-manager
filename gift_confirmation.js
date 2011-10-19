function parseParams(string) {
  var list = string.slice(1, -1).split('&'), result = {}, item;
  for (var i = 0, len = list.length; i < len; i++) {
    item = list[i].split('=');
    result[item[0]] = item[1];
  }

  return result;
}

var params = parseParams(window.location.hash)['view-params'], token;

try {
  params = JSON.parse(decodeURIComponent(params));
  if (params['page'] == 'acceptedGift') {
    token = params['token'];
  }
} catch (e) {
}

if (token) {
  var giftCheck = setInterval(function() {
    var confirmation = document.getElementsByClassName('giftPage');
    if (confirmation.length == 1) {
      clearInterval(giftCheck);
      confirmation = confirmation[0].innerText;
      if (/\b(successfully|already)\b/i.test(confirmation)) {
        Account.claimGift(token, function(gift) {
          console.log(arguments);
        })
        chrome.extension.sendRequest({markClaim: token});
      } else if (/\berror\b/i.test(confirmation)) {
        chrome.extension.sendRequest({claimError: token});
      } else if (/\bexpired\b/.test(confirmation)) {
        chrome.extension.sendRequest({claimExpired: token});
      } else if (/\bstolen\b/.test(confirmation)) {
        // We couldn't find that gift in our databases. A hurlock must have stolen it!
        chrome.extension.sendRequest({claimStolen: token});
      }

      // chrome.extension.sendRequest({getGifters: true}, function(gifters) {
        var tabs = document.getElementById('tabs'), link = document.createElement('a');
        link.setAttribute('class', 'tab');
        link.setAttribute('onclick', "(" + (function() {
          requestGifting(true, {url: giftingParams.url, success: function (data) {
            onGiftContainerShow(data);

            var buttons = document.getElementById('giftForm').getElementsByClassName('giftHeadline')[0],
                link = buttons.childNodes[1], event = document.createEvent("Events");
                // link = document.createElement('input');
            // link.setAttribute('type', 'button');
            // link.setAttribute('class', 'giftButton giftSendButton');
            // buttons.insertBefore(link, buttons.childNodes[0]);
            link.setAttribute('value', 'Send to All >>');

            event.initEvent('autogift', true, true);
            link.dispatchEvent(event);
          }, data: giftingParams.data});
        }).toString().slice(0, -2) + "})();");
        link.id = "customTab";
        link.innerText = 'Auto Gift';
        tabs.insertBefore(link, tabs.childNodes[0]);

        window.addEventListener('autogift', function(event) {
          event.target.addEventListener('click', function() {
            chrome.extension.sendRequest({sendingGift: true});
          });
        });
    }
  }, 1000), timeout = setTimeout(function() {
    clearInterval(giftCheck);
    chrome.extension.sendRequest({claimTimeout: token});
  }, 15000);
}
