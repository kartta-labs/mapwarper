class Api::V1::LayersController < Api::V1::ApiController
  before_filter :authenticate_user!,       :except => [:show, :index, :tilejson]
  before_filter :check_administrator_role, :only => [:toggle_visibility, :merge]
  before_filter :find_layer,               :only =>   [:show, :update, :destroy, :toggle_visibility, :remove_map, :merge, :tilejson]
  before_filter :can_edit_layer, :only => [:update, :destroy, :remove_map]
  before_filter :validate_jsonapi_type,:only => [:create, :update]
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  rescue_from ActionController::ParameterMissing, with: :missing_param_error
  
  def show
    if request.format == "geojson"
      render :json  => @layer, :serializer => LayerGeoSerializer, :adapter => :attributes
      return
    end
    
    render :json => @layer
  end
  
  def create
    @layer = Layer.new(layer_params)
    @layer.user = current_user

    if params[:data][:map_ids]
      selected_maps = Map.find(params[:data][:map_ids])
      selected_maps.each {|map| @layer.maps << map}
    end

    if @layer.save
      @layer.update_layer
      @layer.update_counts
      render :json => @layer, :status => :created
    else
      render :json => @layer, :status => :unprocessable_entity, :serializer => ActiveModel::Serializer::ErrorSerializer 
    end
  end

  def update
    if @layer.update_attributes(layer_params)
      if params[:data][:map_ids]
        selected_maps = Map.find(params[:data][:map_ids])
        selected_maps.each {|map| @layer.maps << map}
        @layer.update_layer
        @layer.update_counts
      end

      render :json => @layer
    else
      render :json => @layer, :status => :unprocessable_entity, :serializer => ActiveModel::Serializer::ErrorSerializer 
    end
  end
    
  def destroy
    if @layer.destroy
      render :json => @layer
    else
      render :json => { :errors => [{:title => "Layer error", :detail => "Error deleting layer"}] },:status => :unprocessable_entity
    end
  end
  
  #patch
  def toggle_visibility
    @layer.is_visible = !@layer.is_visible
    @layer.save
    @layer.update_layer
 
    render :json => @layer
  end
 
  def remove_map
    map = Map.find(params[:map_id])
    
    if @layer.remove_map(map.id)
      render :json => @layer
    else
      render :json => { :errors => [{:title => "Layer error", :detail => "Error removing map."}] }, :status => :unprocessable_entity
    end
  end

  #merge this layer with another one
  #moves all child object to new parent
  def merge
    dest_layer = Layer.find(params[:dest_id])
    if @layer.merge(dest_layer.id)
      render :json => dest_layer
    else
      render :json => { :errors => [{:title => "Layer error", :detail => "Error merging layers"}] }, :status => :unprocessable_entity
    end
  end
  
  
#index 
def index
    
  #map_conditions
  #maps/map_id/layers 
  map_conditions = nil
  if index_params[:map_id]
    map = Map.find(index_params[:map_id])
    map_conditions = {id: map.layers.map(&:id)}
  end
    
  #sort / order 
  sort_order = "desc"
  sort_order = "asc" if index_params[:sort_order] == "asc"
  sort_key = %w(name created_at updated_at percent).detect{|f| f == (index_params[:sort_key])}
  sort_key = sort_key || "updated_at" if sort_order == "desc"
  if sort_order == "desc"
    sort_nulls = " NULLS LAST"
  else
    sort_nulls = " NULLS FIRST"
  end
  
  order_options = "#{sort_key} #{sort_order} #{sort_nulls}"
  
  #select percent
  select = "*"
  select_conditions = nil
  if sort_key == "percent"
    select = "*, round(rectified_maps_count::float / maps_count::float * 100) as percent"
    select_conditions = "maps_count > 0"
  end
    
  #pagination
  paginate_options = {
    :page => index_params[:page],
    :per_page => index_params[:per_page] || 50
  }
  
  #query
  query = index_params[:query]
  field = %w(name description).detect{|f| f== (params[:field])}
  field = field || "name"
  query_conditions = nil
  if query && query.strip.length > 0
    query = query.gsub(/\W/, ' ')
    query_conditions =   ["#{field}  ~* ?", '(:punct:|^|)'+query+'([^A-z]|$)']
  end
    
  #bbox geo
  #bbox
  bbox_conditions = nil
  sort_geo = nil
    
  #extents = [-74.1710,40.5883,-73.4809,40.8485] #NYC
  if params[:bbox] && params[:bbox].split(',').size == 4
    extents  = nil
    begin
      extents = params[:bbox].split(',').collect {|i| Float(i)}
    rescue ArgumentError
      logger.debug "arg error with bbox, setting extent to defaults"
      #TODO send back error message here instead of defaults
    end
    if extents 
      bbox_poly_ary = [
        [ extents[0], extents[1] ],
        [ extents[2], extents[1] ],
        [ extents[2], extents[3] ],
        [ extents[0], extents[3] ],
        [ extents[0], extents[1] ]
      ]
      bbox_polygon = GeoRuby::SimpleFeatures::Polygon.from_coordinates([bbox_poly_ary], -1).as_ewkt
      if params[:operation] == "within"
        bbox_conditions = ["ST_Within(bbox_geom, ST_GeomFromText('#{bbox_polygon}'))"]
      else
        bbox_conditions = ["ST_Intersects(bbox_geom, ST_GeomFromText('#{bbox_polygon}'))"]
      end
        
      if params[:operation] == "intersect"
        sort_geo = "ABS(ST_Area(bbox_geom) - ST_Area(ST_GeomFromText('#{bbox_polygon}'))) ASC"
      else
        sort_geo ="ST_Area(bbox_geom) DESC"
      end
    end
      
  end
    
  @layers = Layer.select(select).where(select_conditions).where(map_conditions).where(bbox_conditions).where(query_conditions).order(order_options).order(sort_geo).paginate(paginate_options)
 
  if request.format == "geojson"
    render :json  => @layers, :each_serializer => LayerGeoSerializer, :adapter => :attributes
    return
  end  
  
  render :json => @layers, :meta => {
    "total_entries" => @layers.total_entries,
    "total_pages"   => @layers.total_pages}
end
    
#maps
  
def tilejson
  name = ActionController::Base.helpers.sanitize(@layer.name,  :tags => [])

  bbox = @layer.bbox.split(",")
  tile_bbox = [bbox[0].to_f,bbox[1].to_f,bbox[2].to_f,bbox[3].to_f]
  centroid_y = tile_bbox[1] + ((tile_bbox[3] -  tile_bbox[1]) / 2)
  centroid_x = tile_bbox[0] + ((tile_bbox[2] -  tile_bbox[0]) / 2)
  center  = [centroid_x, centroid_y, 21 ]
  site_url = APP_CONFIG['host_with_scheme']
  site_name  =  APP_CONFIG['site_name']
  attribution = "From: <a href='#{site_url}/#{@layer.class.to_s.downcase}s/#{@layer.id}/'>#{site_name}</a>" 

  tiles = ["#{tile_layer_base_url(:id => @layer.id)}/{z}/{x}/{y}.png"]
  
  render :json => {tilejson: "2.0.0", autoscale: true, version: "1.5.0", scheme: "xyz", minzoom: 1, maxzoom: 21, name: name, description: "", center: center, bounds: tile_bbox, attribution: attribution, tiles:tiles}.to_json
end

  
  
  
private
  
def layer_params
  params.require(:data).require(:attributes).permit(:name, :description, :source_uri, :depicts_year)
end

def index_params
  params.permit(:page, :per_page, :query, :field, :sort_key, :sort_order, :field,  :bbox, :operation, :format, :map_id)
end
  
def find_layer
  @layer = Layer.find(params[:id])
end

def can_edit_layer
  unless user_signed_in? and ((current_user == @layer.user) or current_user.has_role?("editor"))
    permission_denied
  end
end


end
