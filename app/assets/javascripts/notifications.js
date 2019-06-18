toastr.options = {
  "closeButton": true, "debug": false,  "newestOnTop": false,  "progressBar": true, "positionClass": "toast-bottom-right", "preventDuplicates": true, "onclick": null,
  "showDuration": "900", "hideDuration": "500", "timeOut": "5000","extendedTimeOut": "1000",
  "showEasing": "swing","hideEasing": "linear","showMethod": "fadeIn", "hideMethod": "fadeOut"
}

Notifications = (function() {
  
  function Notifications() {
      //only run this when the Rectify or Crop tabs are active
      setInterval(((function(_this) {
        return function() {
          var activePanelId  = jQuery("#wooTabs .ui-tabs-panel:visible").attr("id");
          if (activePanelId == "Rectify" || activePanelId == "Crop" ) {
            return _this.getLatestNotifications();
          }
        };
      })(this)), 5000);  //every 5 seconds
  
  }

  Notifications.prototype.getLatestNotifications = function() {
    return jQuery.ajax({
      url: "/notifications.json?map=" + current_map_id + "&since="+ current_time,
      dataType: "JSON",
      method: "GET",
      success: this.handleSuccess
    });
  };

  Notifications.prototype.handleSuccess = function(data) {
    var seen = [];
    if (readCookie("_mapwarper_seen_notifications")){
      seen = JSON.parse(readCookie("_mapwarper_seen_notifications"));
    } 
    
    items = jQuery.map(data, function(notification) {
      if (seen.includes(notification.id) ){
        return false;
      }
      seen.push(notification.id)
      var title = I18n["notifications"]["map_changed_title"]
      var kind = I18n["notifications"][notification.kind];

      toastr["info"](notification.by.name + " " + kind + " " + notification.when + " " + I18n["notifications"]["ago"], title)
    });

    createCookie("_mapwarper_seen_notifications", JSON.stringify(seen), 1);
  };

  return Notifications;
})();

jQuery(function() {
  return new Notifications;
});
