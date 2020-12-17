var warpedmap;
var warped_wmslayer;

function get_map_layer(layerid){
  var newlayer_url = layer_baseurl + "/" + layerid;
  var title = I18n['warped']['warped_layer']+" " + layerid;
  var map_layer =   new ol.layer.Tile({
    visible: false,
    title: title,
    source: new ol.source.TileWMS({
      url: newlayer_url,
      projection:  'epsg:3857',
      params: {'FORMAT': 'image/png',TRANSPARENT: 'true', reproject: 'true', 'STATUS': 'warped', 'SRS': 'epsg:3857', units: "m"}
    })
  })
  map_layer.setVisible(false);

  return map_layer;
}

var DateControl = function(opts) {
  var options = opts || {};

  var input = document.createElement("input");
  input.pattern="^[12][0-9]{3}$"
  input.value = options.date || "1850";
  input.title = "Enter in a year"
  var span = document.createElement("span");
  span.className = "datespan"
  span.textContent = "Year"

  var element = document.createElement("div");
  element.className = "date-control ol-unselectable ol-control";
  element.appendChild(span)
  element.appendChild(input)

  var handleChangeDate = function(e){
    var num = Number(e.target.value);
    if (num){
     applyFilter(String(num));
    }
  }

  input.addEventListener("input", handleChangeDate, false);

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
  
};



if ( ol.control.Control ) DateControl.prototype = ol.control.Control;
DateControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
DateControl.prototype.constructor = DateControl;



var layersToFilter = [
  "water",
  "buildings",
  "building_names",
  "buildings_outline",
  "road_names",
  "minor_roads",
  "roads_casing_major",
  "roads_centre_major"
];


function warpedinit() {

  //use_tiles usually set when logged out. (quicker and easier to cache these tiles than wms calls)
  if (use_tiles === true){
    warped_wmslayer = new ol.layer.Tile({
      visible: true,
      title: I18n['warped']['warped_map'],
      source: new ol.source.XYZ({
        url: tile_url_templ
      })
    });
  }else{
    warped_wmslayer = new ol.layer.Tile({
      title: I18n['warped']['warped_map'],
      visible: true,
      source: new ol.source.TileWMS({
         url: warpedwms_url,
          projection:  'epsg:3857',
          params: {'FORMAT': 'image/png', 'STATUS': 'warped', 'SRS':'epsg:3857'}
      })
    })
  }
  var opacity = .7;
  warped_wmslayer.setOpacity(opacity);


  var blayers = [ 
    new ol.layer.Tile({
      visible: false,
      type: 'base',
      title: 'Esri World Imagery',
      source: new ol.source.XYZ({
        attributions: 'Source: Esri, DigitalGlobe, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community',
        url: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      })
    }),
    new ol.layer.Tile({ 
      title: 'OpenStreetMap',
      type: 'base',
      visible: false,
      source: new ol.source.OSM(),
      projection: "epsg:3857"
    })
  ]

  if (mapbox_access_token.length > 1) {  //only add it if theres a token for it.
    blayers.unshift(
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

  var overlays = [warped_wmslayer]

  // any mosaics if there are any that the map belongs to
  for (var i = 0; i < layers_array.length; i++) {
    overlays.push(get_map_layer(layers_array[i]));
  }

  var overlay_layers = [
    new ol.layer.Group({
      title: 'Overlays',
      layers:  overlays 
    })
  ];

  warpedmap = new ol.Map({
    layers: [],
    target: 'warpedmap',
    view: new ol.View({
      center: ol.extent.getCenter(warped_extent),
      minZoom: 2,
      maxZoom: 20,
      zoom: 4
    })
  });
  
  var layerSwitcher = new ol.control.LayerSwitcher({
    tipLabel: 'Layers' 
  });
  warpedmap.addControl(layerSwitcher);
  var date = "1850";
  if (depicts_year.length > 0 && Number(depicts_year)){
    date = depicts_year
  }
  var dateControl = new DateControl({
    date: date
  });
  

  var extent;
  if (mask_geojson) {
    var vectorSource = new ol.source.Vector({
      features: (new ol.format.GeoJSON()).readFeatures(mask_geojson)
    });
    extent = vectorSource.getExtent();
  } else {
    extent = ol.proj.transformExtent(warped_extent, 'EPSG:4326', 'EPSG:3857');
  }
  warpedmap.getView().fit(extent, warpedmap.getSize()); 
  
  //set up slider
  jQuery("#slider").slider({
      value: 100 * opacity,
      range: "min",
      slide: function(e, ui) {
          warped_wmslayer.setOpacity(ui.value / 100);
          document.getElementById('opacity').value = ui.value;
      }
  });

  antique_layer = antique_layer_path;

  olms(warpedmap, antique_layer).then(function(map) {
  
   // layer = map.getLayers().getArray().filter(layr => layr.get('mapbox-source') === "antique")[0]; 
    layer = map.getLayers().getArray().filter(function (element) {
      return element.get('mapbox-source') === "antique";
     })[0];

   
    layer.setProperties({title: "Antique Vector Map", type: "base"})
    layer.className_  =  "antiquelayer" // see https://github.com/openlayers/ol-mapbox-style/issues/264

    layer.getSource().setAttributions('Vector Tiles <a href="https://re.city/copyright">Re.City Copyright</a>');

     //add date control first
    warpedmap.addControl(dateControl);

    //listen for if the layer gets turned off and turn off the control too
    layer.on("change:visible", function(e){
      if (e.oldValue == false){
        warpedmap.addControl(dateControl);
      }else {
        warpedmap.removeControl(dateControl);
      }
    })

    var layers = base_layers.concat(overlay_layers); 
    map.getLayers().extend(layers); //This adds layers to map
    date = "1850"
    if (depicts_year.length > 0 && Number(depicts_year)){
      date = depicts_year
    }
    applyFilter(date);
  });

  
} //warpedinit

function applyFilter(date_str){
  var startProp  = 'start_date';
  var endProp    = 'end_date';
   
  var filterStart = ['any',
      ['!', ['has', startProp]],
      ['<=', ['get', startProp], date_str]
    ];
    var filterEnd = ['any',
      ['!', ['has', endProp]],
      ['>=', ['get', endProp], date_str]
    ];

    var newFilters = ['all', filterStart, filterEnd];

 // olms.setFilter(warpedmap, "buildings", ["all",["any",["!",["has","start_date"]],["<=",["get","start_date"],"1850"]],["any",["!",["has","end_date"]],[">=",["get","end_date"],"1850"]]])

    for (var i = 0; i < layersToFilter.length; i++) {
      olms.setFilter(warpedmap, layersToFilter[i],  newFilters)

    }
}


