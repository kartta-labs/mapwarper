class Masking < ActiveRecord::Base
  #
  # A Map has one Masking
  # original_gml - the gml used to mask the unrectified image (currently stored on disk)
  # original_ol_gml - gml used for editing and viewing on openlayers (currently stored on disk)
  # transformed_geojson - rectified / transformed mask in geojson format  <-- only one currently used
  # 
  belongs_to :map
  validates_uniqueness_of :map_id
end