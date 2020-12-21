# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
 Rails.application.config.assets.precompile += %w(layer-maps.js geosearch.js geosearch-map.js geosearch-layer.js warped.js align.js clip.js warp.ol.js openlayers/2.8/OpenLayers-2.8/OpenLayers.js )

Rails.application.config.assets.precompile += %w(*.png *.jpg *.jpeg *.gif)

Rails.application.config.assets.precompile += %w( select2/select2.min.js select2/select2.min.css select2/i18n/nl.js)
Rails.application.config.assets.precompile += %w( helmerttransform.js )
Rails.application.config.assets.precompile += %w( bootstrap-native-v4.min.js  )
Rails.application.config.assets.precompile += %w( fabric.min.js fabriclayer.js  )
Rails.application.config.assets.precompile += %w( masonry.pkgd.min.js imagesloaded.pkgd.min.js  )