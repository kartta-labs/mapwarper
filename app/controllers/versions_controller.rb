class VersionsController < ApplicationController
  layout "application"
  
  before_filter :authenticate_user!
  
  before_filter :check_administrator_role, :only => [:revert_map, :revert_gcp]
  def show
    @version  =  PaperTrail::Version.find(params[:id])
  end

  def index
    @html_title = t('.html_title')
    @versions = PaperTrail::Version.order(:created_at => :desc).paginate(:page => params[:page],
      :per_page => 50)
    @title =  t('.title')
    @linktomap = true
    render :action => 'index'
  end


  def for_user
    user_id = params[:id].to_i
    @user = User.where(id: user_id).first
    if @user
      @html_title = t('.html_title', user: @user.login.capitalize)
      @title = t('.title', user: @user.login.capitalize)
    else
      @html_title = "#{t('.html_title_nouser')} #{params[:id]}"
      @title = "#{t('.title_nouser')} #{params[:id]}"
    end    
    
    order_options = "created_at DESC"
   
    @versions = PaperTrail::Version.where(:whodunnit => user_id).order(order_options).paginate(:page => params[:page],
      :per_page => 50)
    
    render :action => 'index'
  end

  def for_map
    @selected_tab = 5
    @current_tab = "activity"
    @map = Map.find(params[:id])
    @html_title = t('.html_title', map: @map.id.to_s)
    
    order_options = "created_at DESC"
   
    @versions =  PaperTrail::Version.where("item_type = 'Map' AND item_id = ?", @map.id).order(order_options).paginate(:page => params[:page], :per_page => 20)

    @title = t('.title', map: params[:id].to_s)
    respond_to do | format |
      if request.xhr?
        @xhr_flag = "xhr"
        format.html { render  :layout => 'tab_container' }
      else
        format.html {render :layout => 'application' }
      end
      format.rss {render :action=> 'index'}
    end
  end
  
  def for_map_model
    @html_title = t('.html_title')
    order_options = "created_at DESC"
    
    @versions =  PaperTrail::Version.where(:item_type => 'Map').order(order_options).paginate(:page => params[:page], :per_page => 20)

    @title = t('.title')
    render :action => 'index'
  end
  
  def revert_map
    @version = PaperTrail::Version.find(params[:id])
    if @version.item_type != "Map"
      flash[:error] = t('.not_map')
      return redirect_to :activity_details
    else
      map = Map.find(@version.item_id)
      reified_map = @version.reify(:has_many => true)
      new_gcps = reified_map.gcps.to_a
      map.gcps = new_gcps
      flash[:notice] = t('.reverted')
      return redirect_to :activity_details
    end
  end
  
  def revert_gcp
    @version = PaperTrail::Version.find(params[:id])
    if @version.item_type != "Gcp"
      flash[:error] = t('.not_gcp')
      return redirect_to :activity_details
    else
      if @version.event == "create"
        if Gcp.exists?(@version.item_id.to_i)
          gcp = Gcp.find(@version.item_id.to_i)
          gcp.destroy
          flash[:notice] = t('.reverted_deleted')
          return redirect_to :activity_details
        end
      else
        gcp = @version.reify
        gcp.save 
        flash[:notice] = t('.reverted')
        return redirect_to :activity_details
      end
    end
    
  end

end
