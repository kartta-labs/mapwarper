var un_bounds;
var umap;
function uinit() { 
  unwarped_init();
}

function unwarped_init() {
  un_bounds =  [0, 0, unwarped_image_width, unwarped_image_height];
  var extent = un_bounds;

  if (typeof (umap) == 'undefined') {
    var projection = new ol.proj.Projection({
      code: 'EPSG:32663',
      units: 'm'
    });
    var layers = [
      new ol.layer.Tile({
        source: new ol.source.TileWMS({
          extent: extent,
          url: wms_url,
          projection:  projection,
          params: {'FORMAT': 'image/png', 'STATUS': 'unwarped', 'SRS':'epsg:4326'}
        })
      })
    ];
    umap = new ol.Map({
      layers: layers,
      target: 'unmap',
      view: new ol.View({
        center: ol.extent.getCenter(extent),
        minZoom: -4,
        maxZoom: 6,
        maxResolution: 10.496,
        projection: projection
      })
    });
    umap.getView().fit(extent, umap.getSize()); 
  }

};
