function toggleUserMenu() {
  $e = jQuery("header.hms-common div.dropdown.user-menu");
  if ($e && $e.hasClass("open")) {
    $e.removeClass("open");
  } else {
    $e.addClass("open");
  }
}

$(document).ready(function() {
  $e = jQuery("header.hms-common a.hms-dropdown-toggle");
  if ($e) {
    $e.click(toggleUserMenu);
  }
});
