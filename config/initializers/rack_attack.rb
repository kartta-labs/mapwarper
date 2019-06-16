class Rack::Attack


  if APP_CONFIG["enable_throttling"] == true
    
    limit =  APP_CONFIG["throttle_limit"]  || 5  #5 requests
    period = APP_CONFIG["throttle_period"] || 20 #20 seconds

    #general rate limiting 300 requests in 5 minutes
    #uncomment to enable
    #Rack::Attack.throttle('req/ip', :limit => 300, :period => 5.minutes) do |req|
    #  req.ip + req.user_agent unless req.path.include?("/assets") || req.path.include?("/wms") || req.path.include?("/tile")
    #end

    # safelist('allow from localhost') do |req|
    #   # Requests are allowed if the return value is truthy
    #   '127.0.0.1' == req.ip || '::1' == req.ip
    # end

    unless APP_CONFIG["throttle_safelist_ips"].blank?
      safe_ips = APP_CONFIG["throttle_safelist_ips"].split(",")
      safelist('allow from defined list') do |req|
        safe_ips.include? req.ip
      end
    end

    # Attacks on logins
    throttle('logins/ip', :limit => 15, :period => 60.seconds) do |req|
      if (req.path.include?('/u/sign_in') || req.path.include?('/auth/sign_in')) && req.post?
        req.ip + req.user_agent.to_s
      end
    end

    #  Limiting other requests, posts
    throttle('warper/post_request', :limit => limit, :period => period.seconds) do |req|
      if (req.path.include?("/rectify") || 
          req.path.include?("/save_mask_and_warp") || 
          req.path.include?("/comments") ||
          req.path.include?("/gcps/add"))  && req.post?
        req.ip + req.user_agent.to_s
      end
    end

    #  Limiting other requests, puts
    throttle('warper/put_request', :limit => limit, :period => period.seconds) do |req|
      if (req.path.include?("/rectify") || req.path.include?("/gcps") || req.path.include?("/comments")) && req.put?
        req.ip + req.user_agent.to_s
      end
    end
    
    throttle('warper/delete_request', :limit => limit, :period => period.seconds) do |req|
      if  (req.path.include?("/maps") || req.path.include?("/gcps")) && req.delete?
        req.ip + req.user_agent.to_s
      end
    end

    #  Limiting requests, admin throttle test
    throttle('admin/throttletest', :limit => limit, :period => period.seconds) do |req|
      if req.path.include?('/throttle_test') && req.get?
        req.ip
      end
    end

    # track this request - it wont get throttled but the application controller will delay the request
    Rack::Attack.track('admin/delaytest', :limit => limit, :period => period.seconds) do |req|
      if req.path.include?('/delay_test') && req.get?
        req.ip
      end
    end

    # # Block suspicious requests for '/etc/password' or wordpress specific paths.
    # # After 3 blocked requests in 10 minutes, block all requests from that IP for 5 minutes.
    # Rack::Attack.blocklist('fail2ban pentesters') do |req|
    #   # `filter` returns truthy value if request fails, or if it's from a previously banned IP
    #   # so the request is blocked
    #   Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 5.minutes) do
    #     # The count for the IP is incremented if the return value is truthy
    #     CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
    #     req.path.include?('/etc/passwd') ||
    #     req.path.include?('wp-admin') ||
    #     req.path.include?('wp-login') ||
    #     req.path.include?('phpmyadmin')
    #   end
    # end


  end

end

ActiveSupport::Notifications.subscribe("track.rack_attack") do |name, start, finish, request_id, payload|
  req = payload[:request]
  if req.env['rack.attack.matched'] == "admin/delaytest"
    Rails.logger.debug "delay test, delay"
    req.env['rack.attack.delay_request'] = true
  end
end