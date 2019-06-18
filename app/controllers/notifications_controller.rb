class NotificationsController < ApplicationController
  before_filter :authenticate_user!
  rescue_from ActiveRecord::RecordNotFound, :with => :bad_record

  def index
    where_opts = nil
    if params[:map]
      where_opts = ["notifiable_type = 'Map' and notifiable_id = ?", params[:map].to_i]
    end
    since_opts = nil
    if params[:since]
      since_opts = ["created_at > ?", Time.at(params[:since].to_i)]
    end
    @notifications = Notification.latest.where.not(actor: current_user).where(where_opts).where(since_opts)
 
    render :json  => @notifications, :adapter => :attributes
  end


  private

  def bad_record
    respond_to do | format |
      format.html do
        flash[:notice] = "Not found"
        redirect_to :root
      end
      format.json {render :json => {:stat => "not found", :items =>[]}.to_json, :status => 404}
    end
  end
end