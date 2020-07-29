require 'devise/strategies/authenticatable'
#
# This authentication strategy authenticates the super based on the presense of a header. 
#
module Devise
  module Strategies
    class XEmailHeaderAuthenticatable < Authenticatable

      def valid?
        env['HTTP_X_EMAIL'] 
      end

      def store?
        false
      end

      def authenticate!
	email = env['HTTP_X_EMAIL']
        if email
          if user = User.find_by(email: email)
            success!(user)
          else
	    redirect!(APP_CONFIG['signup_url'],
		      # referer probably does not matter here, as after Sign UP we show
		      # the Welcome page
		      "referer" => APP_CONFIG['site_prefix'])
	    throw :warden
          end
        end
      end
      
    end
  end
end

Warden::Strategies.add(:x_email_header_authenticatable, Devise::Strategies::XEmailHeaderAuthenticatable)
