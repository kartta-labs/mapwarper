class Api::V1::ActivityController < Api::V1::ApiController
  include ActionController::Serialization
  before_filter :authenticate_user!
  before_filter :check_administrator_role, :only => [:stats]
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
    
  def stats
    sort_order = "desc"
    sort_order = "asc" if params[:sort_order] == "asc"
    sort_key = %w(total_count map_count gcp_count gcp_update_count gcp_create_count gcp_destroy_count whodunnit ).detect{|f| f == (params[:sort_key])}
    sort_key = sort_key || "total_count" if sort_order == "desc"
  
    order_options = "#{sort_key} #{sort_order}"

    period = params[:period]
    period_where_clause = ""

    if period == "hour"
      period_where_clause = "where created_at > '#{1.hour.ago.to_s(:db)}'"
    elsif period == "day"
      period_where_clause = "where created_at > '#{1.day.ago.to_s(:db)}'"
    elsif period == "week"
      period_where_clause = "where created_at > '#{1.week.ago.to_s(:db)}'"
    elsif period == "month"
      period_where_clause = "where created_at > '#{1.month.ago.to_s(:db)}'"
    else
      period = "total"
      period_where_clause = "" 
    end

    the_sql = "select whodunnit, COUNT(whodunnit) as total_count,
    COUNT(case when item_type='Gcp' then 1 end) as gcp_count,
    COUNT(case when item_type='Map' or item_type='Mapscan' then 1 end) as map_count,
    COUNT(case when event='update' and item_type='Gcp' then 1 end) as gcp_update_count,
    COUNT(case when event='create' and item_type='Gcp' then 1 end) as gcp_create_count,
    COUNT(case when event='destroy' and item_type='Gcp' then 1 end) as gcp_destroy_count 
    from versions #{period_where_clause} group by whodunnit ORDER BY #{order_options}"
  
    versions  = PaperTrail::Version.paginate_by_sql(the_sql,:page => params[:page], :per_page => 50)
    
    render :json  => versions, :meta => { "total_entries" => versions.total_entries, "total_pages"   => versions.total_pages}, :each_serializer => StatsSerializer, :adapter => :json
  end
  
  def index
    order_options = "created_at DESC"
    versions = get_versions(nil, order_options)
    
    render_json(versions)
  end
  
  
  def map_index
    order_options = "created_at DESC"
    where_options = ['item_type = ?', 'Map']
    versions = get_versions(where_options, order_options)

    render_json(versions)
  end
  
  def for_map
    map = Map.find(params[:id])
 
    order_options = "created_at DESC"
    where_options = ["item_type = 'Map' AND item_id = ?", map.id]
    versions = get_versions(where_options, order_options)
    
    render_json(versions)
  end
  

  def for_user
    user_id = params[:id].to_i
    user = User.find_by_id(user_id)

    order_options = "created_at DESC"
    where_options = {:whodunnit => user_id}
    versions = get_versions(where_options, order_options)
    
    render_json(versions)
  end

  private
  
  def paginate_options
    {
      :page => params[:page],
      :per_page => params[:per_page] || 50
    }
  end
  
  def get_versions(where_options, order_options)
    select = "id, item_type, item_id, event, whodunnit, created_at, transaction_id"
    PaperTrail::Version.select(select).where(where_options).order(order_options).paginate(paginate_options)
  end

  def render_json(versions)
    render :json  => versions, :meta => { "total_entries" => versions.total_entries, "total_pages"   => versions.total_pages}, :each_serializer => VersionSerializer
  end


  
end 

