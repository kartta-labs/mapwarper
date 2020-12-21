class Masking < ActiveRecord::Base
  #
  # A Map has one Masking
  # original - the mask used to mask the unrectified image by gdal (2d cartesian image coord system, flipped to account for height and different origins)
  # original_ol - mask used for editing and viewing on openlayers (2d cartesian image coord system)
  # transformed_geojson - rectified / transformed mask in geojson format, warped, epsg 4236. Used in geosearch for example to show outlines of maps.
  # geojson - 3857 warped, projected geojson of masks. 
  # 
  belongs_to :map
  validates_uniqueness_of :map_id

  alias_attribute :original, :original_gml
  alias_attribute :original_ol, :original_ol_gml


  def has_or_create_original_ol
    return true if original_ol

    reg_geojson = nil
    ol_geojson = nil
    if File.exists?(map.masking_file_gml)
      reg_command =["ogr2ogr", "-f", "geojson", "/dev/stdout", map.masking_file_gml]
      logger.debug reg_command
      reg_out, reg_err = Open3.capture3( *reg_command )

      if !reg_err.blank? 
        logger.error  "Error ogr2ogr script" + reg_err
        logger.error  "output = "+reg_out
        reg_out = nil
      end

      reg_geojson = reg_out 
    end

    if File.exists?(map.masking_file_gml+".ol")
      ol_command =["ogr2ogr", "-f", "geojson", "/dev/stdout", map.masking_file_gml+".ol"]
      logger.debug ol_command
      ol_out, ol_err = Open3.capture3( *ol_command )

      if !ol_err.blank? 
        logger.error "Error ogr2ogr script" + ol_err
        logger.error  "output = "+ol_out
        ol_out = nil
      end

      ol_geojson = ol_out 
    end

    if reg_geojson || ol_geojson
     # logger.debug "reg #{reg_geojson} ol #{ol_geojson}"
      self.update({original: reg_geojson, original_ol: ol_geojson })
      return true
    else
      return false
    end


  end
end