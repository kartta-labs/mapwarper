var layerMap;
var mapIndexLayer;
var mapIndexSelCtrl;
var selectedFeature;


function init(){

  wmslayer = new ol.layer.Tile({
    title: "Mosaic " + layer_id,
    visible: true,
    source: new ol.source.TileWMS({
        url: warpedwms_url,
        projection:  'epsg:3857',
        params: {'FORMAT': 'image/png', 'STATUS': 'warped', 'SRS':'epsg:3857'}
    })
  });

  var opacity = 1;
  wmslayer.setOpacity(opacity);

  var blayers = [ 
    new ol.layer.Tile({ 
      title: 'OpenStreetMap',
      type: 'base',
      visible: true,
      source: new ol.source.OSM() 
    }),
    new ol.layer.Tile({
      visible: false,
      type: 'base',
      title: 'Esri World Imagery',
      source: new ol.source.XYZ({
        attributions: 'Source: Esri, DigitalGlobe, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community',
        url: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      })
    })
  ]

  if (mapbox_access_token.length > 1) {  //only add it if theres a token for it.
    blayers.push(
      new ol.layer.Tile({
        visible: false,
        type: 'base',
        title: 'Mapbox Satellite',
        source: new ol.source.XYZ({
          attributions: I18n['layers']['mbox_satellite_attribution'],
          url: "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}?access_token="+ mapbox_access_token
        })
      })
    )
  } 

  var base_layers = [ new ol.layer.Group({
      title: 'Base Layer',
      layers: blayers
      })
    ] ;

  var styles = [
    new ol.style.Style({
      stroke: new ol.style.Stroke({
        color: 'red',
        width: 3
      }),
      fill: new ol.style.Fill({
        color: 'rgba(255, 0, 0, 0)'
      })
    })
  ];

  mapIndexLayer = new ol.layer.Vector({
    title: I18n['layers']['map_outlines_label'],
    visible: false,
    source: new ol.source.Vector({  features: [] }),
    style: styles
  });

  var overlay_layers = [
    new ol.layer.Group({
      title: 'Overlays',
      layers:  [wmslayer, mapIndexLayer]
    })
  ];

  var layers = base_layers.concat(overlay_layers); 

  layerMap = new ol.Map({
    layers: layers,
    target: 'map',
    view: new ol.View({
      minZoom: 2,
      maxZoom: 20,
      center: ol.extent.getCenter(warped_bounds.toArray())
    })
  });

  var layerSwitcher = new ol.control.LayerSwitcher({
    tipLabel: 'Layers' 
  });
  layerMap.addControl(layerSwitcher);

  var extent = ol.proj.transformExtent(warped_bounds.toArray(), 'EPSG:4326', 'EPSG:3857');
  layerMap.getView().fit(extent, layerMap.getSize()); 

  jQuery("#layer-slider").slider({
      value: 100,
      range: "min",
      slide: function(e, ui) {
        wmslayer.setOpacity(ui.value / 100);
        OpenLayers.Util.getElement('opacity').value = ui.value;
      }
    });

  loadMapFeatures();

  jQuery("#view-maps-index-link").append("(<a href='javascript:toggleMapIndexLayer();'>"+I18n['layers']['map_outlines_toggle']+"</a>)");

  //Add popup interaction on map bounding boxes
  var container = document.getElementById('popup');
  var content = document.getElementById('popup-content');
  var closer = document.getElementById('popup-closer')
  container.style.visibility = "visible";

  var popup = new ol.Overlay({
    element: container,
    autoPan: true,
    positioning: 'bottom-center',
    autoPanAnimation: {
      duration: 250
    }
  });

  closer.onclick = function() {
    popup.setPosition(undefined);
    closer.blur();
    return false;
  };

  layerMap.addOverlay(popup);

  layerMap.on('click', function(evt) {
    var feature = layerMap.forEachFeatureAtPixel(evt.pixel,
      function(feature) {
        return feature;
      });
    if (feature) {
      var coordinates = evt.coordinate;
      popup.setPosition(coordinates);
      content.innerHTML = "<div class='layermap-popup'> Map "+
      feature.get('mapId') + "<br /> <a href='" + mapBaseURL + "/"+ feature.get('mapId') + "' target='_blank'>"+feature.get('mapTitle')+"</a><br />"+
      "<img src='"+mapThumbBaseURL+ feature.get('mapId')+"' height='80'>"+
      "<br /> <a href='"+mapBaseURL+"/"+ feature.get('mapId')+"#Rectify_tab' target='_blank'>"+I18n['layers']['edit_map']+"</a>"+
      "</div>";

    } else {
      popup.setPosition(undefined);
      closer.blur();
    }
  });

}

function toggleMapIndexLayer(){
  var vis = mapIndexLayer.getVisible();
  mapIndexLayer.setVisible(!vis);
}

// TODO This function use old OL library
function loadMapFeatures(){
  var options = {'format': 'json'};
  OpenLayers.loadURL(mapLayersURL,
    options ,
    this,
    loadItems,
    failMessage);
}

// TODO This function use old OL library
function loadItems(resp){
  var g = new OpenLayers.Format.JSON();  
  jobj = g.read(resp.responseText);
  lmaps = jobj.items;
  for (var a=0;a<lmaps.length;a++){
    var lmap = lmaps[a];
    addMapToMapLayer(lmap);
  }
}

function failMessage(resp){
  alert(I18n['layers']['loading_fail']);
}

function addMapToMapLayer(mapitem){
  var bbox_array = mapitem.bbox.split(",").map(Number);
  var bbox = ol.proj.transformExtent(bbox_array, 'EPSG:4326', 'EPSG:3857');

  var feature = new ol.Feature({
    geometry: new ol.geom.Polygon.fromExtent(bbox),
    name: mapitem.title,
    mapTitle: mapitem.title,
    mapId:   mapitem.id
  });
  mapIndexLayer.getSource().addFeature(feature);
}

