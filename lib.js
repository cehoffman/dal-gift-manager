function giftHash(url) {
  var hash = url.match(/%22%3A%22(.*)%22%7D/);
  if (hash) {
    try {
      hash = JSON.parse(atob(hash[1]));
      if (hash['page'] == 'acceptedGift' ) {
        return hash['token'];
      }
    } catch (e) {
      console.log(e);
    }
  }
}

