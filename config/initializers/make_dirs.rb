#create directories if they don't exist
require 'fileutils'
FileUtils.mkdir_p [DST_MAPS_DIR, SRC_MAPS_DIR, TILEINDEX_DIR, MAP_MASK_DIR]
FileUtils.mkdir_p File.join(DST_MAPS_DIR, "/png/")