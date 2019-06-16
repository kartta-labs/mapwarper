class Gcp < ActiveRecord::Base
  require 'csv'
  belongs_to :map
  has_paper_trail
  
  validates_numericality_of :x, :y, :lat, :lon
  validates_presence_of :x, :y, :lat, :lon, :map_id
  validate :unique_coordinates
  
  scope :soft, -> { where(:soft => true)}
  scope :hard, -> { where('soft IS NULL OR soft = ?', false) }
  
  attr_accessor :error
  
  after_update  {|gcp| gcp.map.paper_trail_event = 'gcp_update'  }
  after_create  {|gcp| gcp.map.paper_trail_event = 'gcp_create'  }
  
  after_save :touch_map

  after_destroy {|gcp| gcp.map.paper_trail_event = 'gcp_delete' if gcp.map  }
  after_destroy :touch_map
  
  def gdal_string
	
    gdal_string = " -gcp " + x.to_s + ", " + y.to_s + ", " + lon.to_s + ", " + lat.to_s

  end

  def gdal_array
    ["-gcp", x.to_s ,  y.to_s, lon.to_s, lat.to_s]
  end
  
  def self.add_many_from_json(gcps_array)
    gcps = []
    
    Gcp.transaction do
      gcps_array.each do | new_gcp|
        if new_gcp[:mapid]
          map = Map.find new_gcp[:mapid]
          mapid = map.id
        else
          next 
        end
        map_id,x,y,lat,lon,name = mapid, new_gcp[:x].to_f, new_gcp[:y].to_f, new_gcp[:lat].to_f, new_gcp[:lon].to_f, new_gcp[:name]
        
        gcp_conditions = {:map_id=>map_id, :x=>x, :y=>y, :lat=>lat, :lon=>lon}
        
        #don't save exactly the same point
        unless Gcp.exists?(gcp_conditions)
          gcp = Gcp.new(gcp_conditions.merge({:name => name}))
          gcp.save
          gcps << gcp
        end
      end
    end
    return gcps
  end

 #for a specific map, csv will be x,y,lon,lat,name
 #for multiple maps csv will be mapid,x,y,lon,lat,name
  def self.add_many_from_file(file, mapid=nil)
    gcps = []
    data = open(file)
    points = CSV.parse(data, :headers =>true, :header_converters => :symbol, :col_sep => ",")
    points.by_row!

    #<CSV::Table mode:row row_count:3>
    #<CSV::Row x:"1.1" y:"2.1" lon:"3.2" lat:"3.2" name:nil>
    #<CSV::Row x:"1.1" y:"2.1" lon:"3.2" lat:"3.2" name:"foo">
    Gcp.transaction do
      points.each do | point |

        next unless point.size > 0
        
        map_id = nil
        
        if mapid
          map = Map.find mapid
          map_id = map.id
        end
        
        if point[:mapid]
          map = Map.find point[:mapid].to_i
          map_id = map.id
        end

        next if map_id == nil 
        
        name = point[:name]
        gcp_conditions = {:x => point[:x].to_f, :y => point[:y].to_f, :lon => point[:lon].to_f, :lat => point[:lat].to_f, :map_id => map_id}
        
        #don't save exactly the same point
        unless Gcp.exists?(gcp_conditions)
          gcp = Gcp.new(gcp_conditions.merge({:name => name}))
          gcp.save
          gcps << gcp
        end

      end #points
    end #transaction
    
    return gcps
  end
  
  def self.to_csv
    CSV.generate do |csv|
      csv << ["x", "y", "lon", "lat"] ## Header values of CSV
      all.each do |g|
        csv << [g.x, g.y, g.lon, g.lat] ##Row values of CSV
      end
    end
  end
  
  def self.all_to_csv
    CSV.generate do |csv|
      csv << ["id", "map", "created_at", "updated_at", "x", "y", "lon", "lat"] ## Header values of CSV
      all.each do |g|
        csv << [g.id, g.map_id, g.created_at, g.updated_at, g.x, g.y, g.lon, g.lat] ##Row values of CSV
      end
    end
  end
  
  private
  


  #
  # Validation to check if a point does not have a duplicate x,y or lat,lon with the same map 
  #
  def unique_coordinates
    if new_record?
      if Gcp.exists?({x: x, y: y, lon: lon, lat: lat, map_id: map_id}) || ( Gcp.exists?({x: x, y: y, map_id: map_id}) || Gcp.exists?({lon: lon, lat: lat, map_id: map_id}) )
        errors.add("coordinates", "Coordinates are not unique") 
      end
    else
      if Gcp.where.not(id: id).exists?({x: x, y: y, lon: lon, lat: lat, map_id: map_id}) || ( Gcp.where.not(id: id).exists?({x: x, y: y, map_id: map_id}) || Gcp.where.not(id: id).exists?({lon: lon, lat: lat, map_id: map_id}) )
        errors.add("coordinates", "Coordinates are not unique") 
      end
    end
  end

  #We want to be able to ensure the map has a version when a gcp is changed
  # NOTE "my_model.paper_trail.touch_with_version is deprecated, please use my_model.paper_trail.save_with_version, which is slightly different. It's a save, not a touch, so make sure you understand the difference by reading the ActiveRecord documentation for both."
  # However save_with_version does not accept args... so we will ignore this warning for the moment
  def touch_map
    self.map.paper_trail.touch_with_version(:gcp_touched_at) if self.map
  end
  
end
