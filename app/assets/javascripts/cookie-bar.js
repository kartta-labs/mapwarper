function allowCookies() {
  createCookie("allow_cookies", "yes");
  $('#cookie-bar').remove();
}

$(document).ready(function() {
  $e = $("div.cookie-ok");
  if ($e) {
    $e.click(allowCookies);
  }
});
