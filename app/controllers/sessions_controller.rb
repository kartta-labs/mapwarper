class SessionsController < Devise::SessionsController
  skip_before_filter :verify_authenticity_token #, :if => :json_request?
  skip_before_action :verify_signed_out_user

  respond_to :html, :json

  def destroy
    sign_out
    redirect_to(APP_CONFIG['signout_url'] || root_path) and return
  end
  
  protected
 
  def json_request?
    request.format.json?
  end
end
