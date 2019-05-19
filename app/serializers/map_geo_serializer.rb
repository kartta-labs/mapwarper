class MapGeoSerializer < ActiveModel::Serializer
  attributes :id, :type, :properties, :geometry

  def type
    "Feature"
  end

  def properties
    { title: object.title, description: object.description, width: object.width, height: object.height, 
      status: object.status, created_at: object.created_at, bbox: object.bbox, thumb_url: object.upload.url(:thumb) }
  end

  def geometry
    if object.bbox_geom && instance_options[:geo] == "bbox"
      polygon = GeoRuby::SimpleFeatures::Polygon.from_ewkt(object.bbox_geom.as_text)
      coords = polygon.as_json[:coordinates]
    elsif instance_options[:geo] == "mask" && object.masking && object.masking.transformed_geojson
      coords = JSON.parse(object.masking.transformed_geojson)["features"][0]["geometry"]["coordinates"]
    else
      coords = []
    end
    {type: "Polygon", coordinates: coords}
  end

end