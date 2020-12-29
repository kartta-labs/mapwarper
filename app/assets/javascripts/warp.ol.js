var temp_gcp_status = false;
var from_templl;
var to_templl;
var warped_layer; //the warped wms layer
var to_layer_switcher;
var navig;
var navigFrom;
var to_vectors;
var from_vectors;
var active_to_vectors;
var active_from_vectors;
var transformation = new olt.transform.Helmert();
var dialogOpen = false;
var layerSwitcher;

DrawPointControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'draw-point-button';
  var element = document.createElement('div');
  element.title = I18n["warp"]["add_gcp"];
  element.className = 'draw-point ol-unselectable ol-control';
  element.appendChild(button);

  options.draw.setActive(false); //default inactive

  var drawPoint = function(e) {
    options.draw.setActive(true);
    options.modify.setActive(false);
    options.dragpan.setActive(false)
  };

  button.addEventListener('click', drawPoint, false);

  options.draw.on("change:active", function(e){
    if (e.oldValue == false){
      element.classList.add("ol-active");
    } else {
      element.classList.remove("ol-active");
    }
  })

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) DrawPointControl.prototype = ol.control.Control;
DrawPointControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
DrawPointControl.prototype.constructor = DrawPointControl;


ModifyPointControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'modify-point-button';
  var element = document.createElement('div');
  element.title = I18n["warp"]["move_gcp"];
  element.className = 'modify-point ol-unselectable ol-control';
  element.appendChild(button);

  options.modify.setActive(false); //default inactive

  var movePoint = function(e) {
    options.modify.setActive(true);
    options.draw.setActive(false);
    options.dragpan.setActive(false);
  };

  button.addEventListener('click', movePoint, false);

  options.modify.on("change:active", function(e){
    if (e.oldValue == false){
      element.classList.add("ol-active");
    } else {
      element.classList.remove("ol-active");
    }
  })

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) ModifyPointControl.prototype = ol.control.Control;
ModifyPointControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
ModifyPointControl.prototype.constructor = ModifyPointControl;

DragPanControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'drag-pan-button';
  var element = document.createElement('div');
  element.title = I18n["warp"]["move_map"];
  element.className = 'drag-pan ol-unselectable ol-control ol-active';
  element.appendChild(button);

  options.dragpan.setActive(true); //default inactive

  var dragpan = function(e) {
    options.dragpan.setActive(true);
    options.modify.setActive(false);
    options.draw.setActive(false);
  };

  button.addEventListener('click', dragpan, false);

  options.dragpan.on("change:active", function(e){
    if (e.oldValue == false){
      element.classList.add("ol-active");
    } else {
      element.classList.remove("ol-active");
    }
  })

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) DragPanControl.prototype = ol.control.Control;
DragPanControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
DragPanControl.prototype.constructor = DragPanControl;

AddLayerControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'add-layer-button';
  var element = document.createElement('div');
  element.title = I18n["warp"]["custom_layer_title"];
  element.className = 'add-layer ol-unselectable ol-control';
  element.appendChild(button);

  var addlayer = function(e) {
    addCustomLayerAction();
  };

  function addCustomLayerAction() {

    var dialog = jQuery("#add_custom_layer").dialog({
      bgiframe: true,
      height: 350,
      width: 500,
      resizable: false,
      draggable: false,
      modal: true,
      hide: 'slow',
      title: I18n["warp"]["custom_layer_title"],
      buttons: [{
          text: I18n["warp"]["custom_layer_add_layer_button"],
          click: function () {
            var selected = jQuery('.layer-select').select2("data")[0];
            if (selected.tiles) {
              var layer = {"title": selected.title, "type": selected.type, "template": selected.tiles};
              addCustomLayer(layer);
            }
            dialog.dialog("close");
            form[ 0 ].reset();
          }
        },
        {
          text: I18n["warp"]["custom_layer_cancel_button"],
          click: function () {
            form[ 0 ].reset();
            dialog.dialog("close");
          }
        }],
      open: function(){
        dialogOpen = true;
      },
      close: function () {
        dialogOpen = false;
        form[ 0 ].reset();
      }
    });
    
  var form = dialog.find( "form" ).on( "submit", function( event ) {
      var template = jQuery("#template").val();
      event.preventDefault();
      addCustomLayer(template);
      dialog.dialog("close"); 
    });
   
 }



 function addCustomLayer(layer) {
  var template = layer.template;
  var title = "";
  var type = layer.type;
  var attribution = "";
  var tokens = template.split("/")
  var basetokens = tokens.slice(0, tokens.length - 3)
  var baseurl = basetokens.join("/") + "/";
  
  if (basetokens.length <= 0){
    return false;
  } 

  if (type == "Custom") {
    title = I18n["warp"]["custom_layer"];
    attribution = I18n["warp"]["custom_layer"] + " " + baseurl
  } else {
    title = type + ": " + layer.title.substring(0,20);
    attribution = title + " " + baseurl
  }
 
  var temp_layer = new ol.layer.Tile({
    visible: true,
    type: 'base',
    title: title,
    source: new ol.source.XYZ({
      attributions: attribution,
      url: template
    })
  })

  options.layergroup.getLayers().array_.push(temp_layer);
  options.layerswitcher.showPanel();

  jQuery('#add_layer').hide();
}

  button.addEventListener('click', addlayer, false);

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) AddLayerControl.prototype = ol.control.Control;
AddLayerControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
AddLayerControl.prototype.constructor = AddLayerControl;


var DateControl = function(opts) {
  var options = opts || {};
  this.slider_div_id = "date-slider"
  this.input_id = "date-input"

  var input = document.createElement("input");
  input.id = this.input_id;
  input.pattern="^[12][0-9]{3}$"
  input.value = options.date || "1850";
  input.title = I18n["warp"]["enter_year"];
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
     updateSlider(num);
    }
  }

  input.addEventListener("input", handleChangeDate, false);

  if (options.slider){
    this.slider = true;
    var sliderdiv = document.createElement("div");
    sliderdiv.id = this.slider_div_id;
    var handle =  document.createElement("div");
    handle.className = "ui-slider-handle";
    sliderdiv.appendChild(handle);
    element.appendChild(sliderdiv);
  }

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
      olms.setFilter(to_map, layersToFilter[i],  newFilters)

    }
}

function updateSlider(num){
  var controls = to_map.getControls().getArray();
  var datecontrol;
  for (var a=0; a<controls.length;a++){
    if (controls[a].constructor.name == "DateControl"){
      datecontrol = controls[a];
      break;
    }
  }
  jQuery("#"+datecontrol.slider_div_id).slider("value", num)
}



///////////////////////////////////////////////////////////////////////////////////////////
//
// INIT
//
///////////////////////////////////////////////////////////////////////////////////////////

//set up to map
function init() {

  var from_extent =  [0, 0, image_width, image_height];

  if (typeof (from_map) == 'undefined') {
    var projection = new ol.proj.Projection({
      code: 'EPSG:32663',
      units: 'm'
    });
    var layers = [
      new ol.layer.Tile({
        source: new ol.source.TileWMS({
          extent: from_extent,
          url: wms_url,
          projection:  projection,
          params: {'FORMAT': 'image/png', 'STATUS': 'unwarped', 'SRS':'epsg:4326'}
        })
      })
    ];
    from_map = new ol.Map({
      layers: layers,
      target: 'from_map',
      view: new ol.View({
        center: ol.extent.getCenter(from_extent),
        minZoom: -4,
        maxZoom: 6,
        maxResolution: 10.496,
        projection: projection
      })
    });
    from_map.getView().fit(from_extent, from_map.getSize()); 
  }

  if (typeof (to_map) == 'undefined') {

    warped_layer = new ol.layer.Tile({
      title: I18n['warped']['warped_map'],
      visible: false,
      source: new ol.source.TileWMS({
        url: wms_url,
          projection:  'epsg:3857',
          params: {'TRANSPARENT': 'true', 'reproject':'true','FORMAT': 'image/png', 'STATUS': 'warped', 'SRS':'epsg:3857'}
      })
    })
    var warpedOpacity = 0.6;
    warped_layer.setOpacity(warpedOpacity);
    var esrilayer;
    var blayers = [ 
      esrilayer =  new ol.layer.Tile({
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
        projection: "EPSG:3857"
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
      title: I18n["warp"]["base_layer"],
      layers: blayers
      })
    ] ;

    var overlays = [warped_layer];

     // any mosaics if there are any that the map belongs to
    for (var i = 0; i < layers_array.length; i++) {
      overlays.push(get_map_layer(layers_array[i]));
    }

    var overlay_layers = [
      new ol.layer.Group({
        title: I18n["warp"]["overlays"],
        layers:  overlays 
      })
    ];

    var layers = base_layers.concat(overlay_layers);
    if (map_has_bounds != true) {
       map_bounds = [];
    }
    to_map = new ol.Map({
      layers: [],
      target: 'to_map',
      view: new ol.View({
        minZoom: 2,
        maxZoom: 21,
        zoom: 4,
        pixelRatio: 1,
        resolutions: esrilayer.getSource().getTileGrid().getResolutions()
      })
    });
  }

  layerSwitcher = new ol.control.LayerSwitcher({ tipLabel: 'Layers'  });
  to_map.addControl(layerSwitcher);

  var date = "1850";
  if (depicts_year.length > 0 && Number(depicts_year)){
    date = depicts_year
  }
  var dateControl = new DateControl({
    date: date,
    slider: true
  });

  antique_layer = antique_layer_path;


  olms(to_map, antique_layer).then(function(map) {
  
     layer = map.getLayers().getArray().filter(function (element) {
       return element.get('mapbox-source') === "antique";
      })[0];
 
     layer.setProperties({title: "Antique Vector Map", type: "base"})
     layer.className_  =  "antiquelayer" // see https://github.com/openlayers/ol-mapbox-style/issues/264
     layer.getSource().setAttributions('Vector Tiles <a href="https://re.city/copyright">Re.City Copyright</a>');
 
      //add date control first
     to_map.addControl(dateControl);
 
     //listen for if the layer gets turned off and turn off the control too
     layer.on("change:visible", function(e){
       if (e.oldValue == false){
        to_map.addControl(dateControl);
       }else {
        to_map.removeControl(dateControl);
       }
     })
 
     var layers = base_layers.concat(overlay_layers); 
     map.getLayers().extend(layers); //This adds layers to map
     date = "1850"
     if (depicts_year.length > 0 && Number(depicts_year)){
       date = depicts_year
     }
     applyFilter(date);

    //set up slider
    if (dateControl.slider) {
      jQuery("#"+dateControl.slider_div_id).slider({
        value: date,
        range: "min",
        max: 2020,
        min: 1500,
        step: 5,
        slide: function(e, ui) {
          applyFilter(String(ui.value));
          jQuery("#"+dateControl.input_id).val(ui.value)
        }
      });
    }


   });



  if (map_has_bounds) {
    to_map.getView().fit(ol.proj.transformExtent(map_bounds, 'EPSG:4326', 'EPSG:3857'), to_map.getSize()); 
  } else if (map_center){
    to_map.getView().setCenter(ol.proj.transform(map_center,'EPSG:4326', 'EPSG:3857'));
    to_map.getView().setZoom(15);
  } else if (mask_geojson){
    var vectorSource = new ol.source.Vector({
      features: (new ol.format.GeoJSON()).readFeatures(mask_geojson)
    });
    to_map.getView().fit(vectorSource.getExtent(), to_map.getSize()); 
  } else if (geocode_result && geocode_result.results && geocode_result.results.length > 0){
    showGeocodeResults(geocode_result);
  } else {
      // set to the world
      to_map.getView().setCenter(ol.proj.transform([0,0],'EPSG:4326', 'EPSG:3857'));
      to_map.getView().setZoom(3);
  }

  var drawingStyle = new ol.style.Style({
    image: new ol.style.Circle({
      radius: 1,
      fill: new ol.style.Fill({
        color: 'orange',
        opacity: 0.3
      })
    })
  });

  var active_style = new ol.style.Style({
    image: new ol.style.Icon({
      anchor: [10, 34],
      size: [20,34],
      scale: 0.7,
      anchorXUnits: 'pixels',
      anchorYUnits: 'pixels',
      src: icon_imgPath + "AQUA.png",
    })
  });

  //from map set up

  var active_from_source = new ol.source.Vector({    projection: 'EPSG:32663'  });
  active_from_vectors = new ol.layer.Vector({
    source: active_from_source,
    style:  active_style
  });
  from_map.addLayer(active_from_vectors);

  var from_source = new ol.source.Vector({   projection: 'EPSG:32663', features: new ol.Collection()   });
  from_vectors = new ol.layer.Vector({
    source: from_source,
    style:  active_style
  });
  from_map.addLayer(from_vectors);

  var modify_from = new ol.interaction.Translate({
    layers: [from_vectors],
    hitTolerance: 4,
  });
  from_map.addInteraction(modify_from);

  modify_from.on("translateend", function(e){
    saveDraggedMarker(e.features.getArray()[0], "from")
  })

  var draw_from = new ol.interaction.Draw({
    source: active_from_source,
    type: 'Point',
    style: drawingStyle
  });
  draw_from.on("drawend", function(e) {  newaddGCPfrom(e.feature); });
  from_map.addInteraction(draw_from);

  var dragpan_from = new ol.interaction.DragPan({});
  from_map.addInteraction(dragpan_from);

  var drawPointControl_from  = new DrawPointControl({source: active_from_source, draw: draw_from, modify: modify_from, dragpan: dragpan_from});
  from_map.addControl(drawPointControl_from);

  var modifyPointControl_from  = new ModifyPointControl({source: active_from_source, draw: draw_from, modify: modify_from, dragpan: dragpan_from});
  from_map.addControl(modifyPointControl_from);

  var dragPanControl_from  = new DragPanControl({draw: draw_from, modify: modify_from, dragpan: dragpan_from})
  from_map.addControl(dragPanControl_from);


  //to map set up

  var active_to_source = new ol.source.Vector({  projection: 'EPSG:4326'  });
  active_to_vectors = new ol.layer.Vector({
    zIndex: 1000,
    source: active_to_source,
    style:  active_style
  });
  to_map.addLayer(active_to_vectors);

  var to_source = new ol.source.Vector({ projection: 'EPSG:3857', features: new ol.Collection()  });
  to_vectors = new ol.layer.Vector({
    zIndex: 1001,
    source: to_source,
    style:  active_style
  });
  to_map.addLayer(to_vectors);

  var modify_to = new ol.interaction.Translate({
    layers: [to_vectors],
    hitTolerance: 4
  });
  to_map.addInteraction(modify_to);

  modify_to.on("translateend", function(e){
    saveDraggedMarker(e.features.getArray()[0], "to")
  })

  var draw_to = new ol.interaction.Draw({
    source: active_to_source,
    type: 'Point',
    style: drawingStyle
  });

  draw_to.on("drawend", function(e) {  newaddGCPto(e.feature); });
  to_map.addInteraction(draw_to);

  var dragpan_to = new ol.interaction.DragPan({})
  to_map.addInteraction(dragpan_to)

  var drawPointControl_to  = new DrawPointControl({source: active_to_source, draw: draw_to, modify: modify_to, dragpan: dragpan_to});
  to_map.addControl(drawPointControl_to);

  var modifyPointControl_to  = new ModifyPointControl({source: active_to_source, draw: draw_to, modify: modify_to, dragpan: dragpan_to});
  to_map.addControl(modifyPointControl_to);

  var dragPanControl_to  = new DragPanControl({draw: draw_to, modify: modify_to, dragpan: dragpan_to});
  to_map.addControl(dragPanControl_to);

  /// custom layer button
  var addLayerControl  = new AddLayerControl({map: to_map, layerswitcher: layerSwitcher, layergroup: base_layers[0]});
  to_map.addControl(addLayerControl);

  joinControls(draw_to, draw_from);
  joinControls(modify_to, modify_from);
  joinControls(dragpan_from, dragpan_to);

  //set up jquery slider for warped layer
  jQuery("#warped-slider").slider({
    value: 100 * warpedOpacity,
    range: "min",
    slide: function(e, ui) {
      warped_layer.setOpacity(ui.value / 100);
    }
  });
  jQuery("#warped-slider").hide();
  warped_layer.on('change:visible', function(layer) {
    if (warped_layer.getVisible() === true) {
      jQuery("#warped-slider").show();
    } else {
      jQuery("#warped-slider").hide();
    }
  });

  setupLayerSelect();

  //keyboard shortcuts,and auto place

  var toPosition;
  var fromPosition;
  var mapUnderMouse = "";
  to_map.on("pointermove", function (e) {
    toPosition = e.pixel;
    mapUnderMouse = "to_map";
  })
  from_map.on("pointermove", function (e) {
    fromPosition = e.pixel;
    mapUnderMouse = "from_map";
  })

  // listen 
  document.addEventListener("keydown", function(evt){
    var date_input = document.getElementById("date-input");
    var search_input = document.getElementsByClassName("select2-search__field")[0]
    if (evt.target == date_input || evt.target == search_input ) return true;
   
    if (dialogOpen === true) return true;
    var key = evt.keyCode; 
    if (key == 81 || key == 65) {
      // q key (81) - quick add point - any mode control
      // a key (65) - quick point but with auto placement
      if (mapUnderMouse == "to_map") {
        // var point = to_map.getLonLatFromPixel(toPosition);
        var point = to_map.getCoordinateFromPixel(toPosition);
        var pointFeature = new ol.Feature({
          geometry: new ol.geom.Point([point[0], point[1]])
        });
        active_to_vectors.getSource().addFeature(pointFeature);
        newaddGCPto(pointFeature);
        
        if (key == 65) addAutoFromPoint(pointFeature);
      } else if (mapUnderMouse == "from_map") {
        var point = from_map.getCoordinateFromPixel(fromPosition);
        var pointFeature = new ol.Feature({
          geometry: new ol.geom.Point([point[0], point[1]])
        });
        active_from_vectors.getSource().addFeature(pointFeature);
        newaddGCPfrom(pointFeature);
        if (key == 65) addAutoToPoint(pointFeature);
      }

    } else if (key == 80 || key == 49) {
      // 1, p = (place point)
     // draw: draw_to, modify: modify_to, dragpan: dragpan_to});
      draw_from.setActive(true);
      modify_from.setActive(false);
      dragpan_from.setActive(false);

    } else if (key == 68 || key == 50) {
      // 2, d (drag point)
      draw_from.setActive(false);
      modify_from.setActive(true);
      dragpan_from.setActive(false);
    } else if (key == 77 || key == 51) {
      //3, m (move point)
      draw_from.setActive(false);
      modify_from.setActive(false);
      dragpan_from.setActive(true);
    } else if (key == 13 || key == 69){
      //enter or e to save gcp
      check_if_gcp_ready();
      if (temp_gcp_status) {
        set_gcp();
      }
    }


    
  })

  
} //init




function check_if_gcp_ready() {
  if (to_templl && from_templl) {
    temp_gcp_status = true;
    document.getElementById("addPointDiv").className = "addPointHighlighted";
    document.getElementById("GcpButton").disabled = false;
  } else {
    temp_gcp_status = false;
  }
}

function newaddGCPto(feat) {
  //only have 1 temp marker on the active layer
  var features = active_to_vectors.getSource().getFeatures();
  if (features.length > 0) {
    for (var a = 0; a < features.length; a++) {
      if (features[a] != feat) {
        active_to_vectors.getSource().removeFeature(features[a]);
      }
    }
  }

  var lonlat = feat.getGeometry().getCoordinates();

  highlight(document.getElementById("to_map")); 
  to_templl = lonlat;
  check_if_gcp_ready();
}


function newaddGCPfrom(feat) {
  //only have 1 temp marker on the active layer
  var features = active_from_vectors.getSource().getFeatures();
 
  if (features.length > 0) {
    for (var a = 0; a < features.length; a++) {
      if (features[a].ol_uid != feat.ol_uid) {
        active_from_vectors.getSource().removeFeature(features[a]);
      }
    }
  }
  
  var lonlat = feat.getGeometry().getCoordinates();
  highlight(document.getElementById("from_map")); 
  from_templl = lonlat;
  check_if_gcp_ready();
}

//set points for transformation
function setTransformPoints() {
  var xy = [];
  var XY = [];
  var fromfeatures = from_vectors.getSource().getFeatures();
  var tofeatures = to_vectors.getSource().getFeatures();
  for (var i = 0; i < fromfeatures.length; i++) {
    xy.push(fromfeatures[i].getGeometry().getCoordinates());
    XY.push(tofeatures[i].getGeometry().getCoordinates());
  }
  transformation.setControlPoints(xy, XY);
}

function transform(xy) {
  var pt = transformation.transform(xy);
  return pt;
}
function reverseTransform(xy) {
  var pt = transformation.revers(xy);
  return pt;
}

function addAutoFromPoint(feature) {
  setTransformPoints();
  var from_auto_pt = transformation.revers(feature.getGeometry().getCoordinates());
  var pointFeature = new ol.Feature({
    geometry: new ol.geom.Point(from_auto_pt)
  });
  
  active_from_vectors.getSource().addFeature(pointFeature);
  newaddGCPfrom(pointFeature);
  from_map.getView().setCenter(from_auto_pt);
}

function addAutoToPoint(feature) {
  setTransformPoints();
  var to_auto_pt = transformation.transform(feature.getGeometry().getCoordinates());
  var pointFeature = new ol.Feature({
    geometry: new ol.geom.Point(to_auto_pt)
  });
  active_to_vectors.getSource().addFeature(pointFeature);
  newaddGCPto(pointFeature);
  to_map.getView().setCenter(to_auto_pt);
}

//if first is active, activate the second (Interactions)
function joinControls(first, second) {

  first.on("change:active", function(e){ 
    if (e.oldValue == false){
      second.setActive(true);
    } else {
      second.setActive(false);
    }
  })

  second.on("change:active", function(e){
    if (e.oldValue == true){
      first.setActive(false);
    } else {
      first.setActive(true);
    }
  })

}


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




//blue, green, orange, red
function getColorString(error) {
  var colorString = "";
  if (error < 5) {
    colorString = "";
  } else if (error >= 5 && error < 10) {
    colorString = "_green";
  } else if (error >= 10 && error < 50) {
    colorString = "_orange";
  } else if (error >= 50) {
    colorString = "_red";
  }
  //TODO
  return colorString;
  //return "";
}

function populate_gcps(gcp_id, img_lon, img_lat, dest_lon, dest_lat, error) {
  error = typeof (error) != "undefined" ? error : 0;
  var color = getColorString(error);

  //x y lon lat
  index = gcp_markers.length;
  gcp_markers.push(index); // 0 to 7 or so
  got_lon = img_lon;
  got_lat = image_height - img_lat;

  add_gcp_marker(from_vectors, [got_lon, got_lat], index, gcp_id, color);
  add_gcp_marker(to_vectors,   ol.proj.transform([dest_lon, dest_lat],'EPSG:4326', 'EPSG:3857'),  index, gcp_id, color);
}

function set_gcp() {
  check_if_gcp_ready();
  if (!temp_gcp_status) {
    alert(I18n["warp"]["gcp_premature_alert"]);
    return false;
  } else {
    var from_lonlat = from_templl;
    var to_lonlat = ol.proj.transform(to_templl, 'EPSG:3857', 'EPSG:4326');
    var img_lon = from_lonlat[0];
    var img_lat = from_lonlat[1];
    var proper_img_lat = image_height - img_lat;
    var proper_img_lon = img_lon;

    save_new_gcp(proper_img_lon, proper_img_lat, to_lonlat[0], to_lonlat[1]);

    active_from_vectors.getSource().clear();
    active_to_vectors.getSource().clear();
  }
}

function save_new_gcp(x, y, lon, lat) {

  url = gcp_add_url;
  gcp_notice(I18n["warp"]["gcp_adding"]);
  jQuery('#spinner').show();
  
  var request = jQuery.ajax({
    type: "POST",
    url: url,
    data: {authenticity_token: encodeURIComponent(window._token), x: x, y: y, lat: lat, lon: lon}}
  ).done(function() {
    update_row_numbers();
    jQuery('#spinner').hide();
  }).fail(function() {
    gcp_notice(I18n["warp"]["gcp_failed"]);
  });
  
}

//when a vector marker is dragged, update values on form and save
function saveDraggedMarker(feature, fromto) {
 
  var listele = document.getElementById("gcp" + feature.gcp_id); //listele is a tr
  for (i = 0; i < listele.childNodes.length; i++) {
    listtd = listele.childNodes[i];//listtd is a td

    for (e = 0; e < listtd.childNodes.length; e++) {
      listItem = listtd.childNodes[e]; //listitem is the input field

      if (fromto  == "from") {
        if (listItem.id == "x" + feature.gcp_id) {
          listItem.value = feature.getGeometry().getCoordinates()[0];
        }
        if (listItem.id == "y" + feature.gcp_id) {
          listItem.value = image_height - feature.getGeometry().getCoordinates()[1]
        }
      }
      if (fromto  == "to") {
        var merc = [feature.getGeometry().getCoordinates()[0], feature.getGeometry().getCoordinates()[1]];
        var vll = ol.proj.transform(merc,'EPSG:3857',  'EPSG:4326');
     
        if (listItem.id == "lon" + feature.gcp_id) {
          listItem.value = vll[0];
        }
        if (listItem.id == "lat" + feature.gcp_id) {
          listItem.value = vll[1];
        }
      }
    }//for
  }//for
  update_gcp(feature.gcp_id, listele);
}

function gcp_notice(text) {
  //jquery effect
  jqHighlight('rectifyNotice');
  notice = document.getElementById('gcp_notice');
  notice.textContent = text;
}


//called after initial populate, each delete, and each add
function update_row_numbers() {
  for (var a = 0; a < from_vectors.getSource().getFeatures().length; a++) {
    temp_marker = from_vectors.getSource().getFeatures()[a];
    li_ele = document.getElementById("gcp" + temp_marker.gcp_id);

    inputs = li_ele.getElementsByTagName("input");
    for (var b = 0; b < inputs.length; b++) {
      if (inputs[b].name == "error" + temp_marker.gcp_id) {
        error = inputs[b].value;
      }
    }
    var color = getColorString(error);
    updateGcpColor(from_vectors.getSource().getFeatures()[a], color);
    updateGcpColor(to_vectors.getSource().getFeatures()[a], color);

    span_ele = li_ele.getElementsByTagName("span");
    if (span_ele[0].className == "marker_number") {
      var thishtml = "<img src='" + icon_imgPath + (temp_marker.id_index + 1) + color + ".png' />";
      span_ele[0].innerHTML = thishtml;
    }
  }
  redrawGcpLayers();
}

function redrawGcpLayers() {
  from_vectors.changed();
  to_vectors.changed();
}

function updateGcpColor(marker, color) {
  var image =  new ol.style.Icon({
    anchor: [7, 22],
    size: [14,22],
    anchorXUnits: 'pixels',
    anchorYUnits: 'pixels',
    src: icon_imgPath + (marker.id_index + 1) + color + '.png',
  })
  marker.getStyle().setImage(image);
}

function update_rms(new_rms) {
  fi = document.getElementById('errortitle');
  fi.innerHTML=  I18n["warp"]["rms_error_prefix"]+"(" + new_rms + ")";
}



function delete_markers(gcp_id) {
  for (var a = 0; a < from_vectors.getSource().getFeatures().length; a++) {
    if (from_vectors.getSource().getFeatures()[a].gcp_id == gcp_id) {
      del_from_mark = from_vectors.getSource().getFeatures()[a];
      del_to_mark = to_vectors.getSource().getFeatures()[a];

      from_vectors.getSource().removeFeature(del_from_mark);
      to_vectors.getSource().removeFeature(del_to_mark);
    }
  }
  update_row_numbers();
}



function add_gcp_marker(markers_layer, lonlat,  id_index, gcp_id, color) {
  color = typeof (color) != "undefined" ? color : "";
  id_index = typeof (id_index) != 'undefined' ? id_index : -2;

  var marker_style = new ol.style.Style({
    image: new ol.style.Icon({
      anchor: [7, 22],
      size: [14,22],
      anchorXUnits: 'pixels',
      anchorYUnits: 'pixels',
      src:  icon_imgPath + (id_index + 1) + color + '.png'
    })
  });

  var pointFeature = new ol.Feature({
    geometry: new ol.geom.Point([lonlat[0], lonlat[1]]),
    id_index: id_index,
    gcp_id: gcp_id
  });

  pointFeature.setStyle(marker_style);
  pointFeature.id_index = id_index;
  pointFeature.gcp_id = gcp_id;
  
  markers_layer.getSource().addFeature(pointFeature);

  resetHighlighting();
}

function show_warped_map() {
  warped_layer.setVisible(true);
  warped_layer.getSource().updateParams({'random': Math.random()});
  warped_layer.getSource().refresh();
  layerSwitcher.showPanel();

  //cross tab issue - reloads the rectified map in the preview tab if its there
  if (typeof warpedmap != 'undefined' && typeof warped_wmslayer != 'undefined') {
    warped_wmslayer.getSource().updateParams({'random': Math.random()})
  }
}



function resetHighlighting() {
  document.getElementById("to_map").className = "map-off";
  document.getElementById("from_map").className = "map-off";
  document.getElementById("addPointDiv").className = "addPoint";
  document.getElementById("GcpButton").disabled = true;
}

function highlight(thingToHighlight) {
  thingToHighlight.className = "highlighted";
}

function lonLatToMercatorBounds(llbounds) {
  return ol.proj.transformExtent(llbounds, 'EPSG:4326', 'EPSG:3857'); 
}

function showGeocodeResults(res){
  zoom = 18;
  if (res.results && res.results.length > 0){
    var viewport = res.results[0].geometry.viewport;
    bounds = [viewport.northeast.lng, viewport.northeast.lat, viewport.southwest.lng, viewport.southwest.lat] 
    var results_bounds_merc = lonLatToMercatorBounds(bounds);
    to_map.getView().fit(results_bounds_merc, to_map.getSize()); 

    zoom = to_map.getView().getZoom();
  
    var message = I18n["warp"]["best_guess_message"]+ " " + 
      "<a href='#' onclick='centerToMap(" + res.results[0].geometry.location.lng + "," + res.results[0].geometry.location.lat + "," + zoom + ");return false;'>" + res.results[0].formatted_address + "</a><br />";
    if (res.results.length > 1){
      message = message + I18n["warp"]["other_places"]+":<br />";
      var bounds_other = [];
      var viewport_other;
      var resolution
      var zoom_other;
      for(var a=1;a<res.results.length;a++){
        viewport_other = res.results[a].geometry.viewport;
        bounds_other = [viewport_other.northeast.lng, viewport_other.northeast.lat, viewport_other.southwest.lng, viewport_other.southwest.lat]

        resolution = to_map.getView().getResolutionForExtent(bounds_other);
        zopm_other = to_map.getView().getZoomForResolution(resolution);
        message = message + "<a href='#' onclick='centerToMap(" + res.results[a].geometry.location.lng + "," + res.results[a].geometry.location.lat + "," + zoom_other + ");return false;'>" + res.results[a].formatted_address + "</a><br />"
      }
    }
    jQuery("#to_map_notification_inner").html(message);
    jQuery("#to_map_notification").show('slow'); 
  }

}

function centerToMap(lon, lat, zoom) {
  var newCenter = ol.proj.transform([lon, lat], 'EPSG:4326', 'EPSG:3857');
  to_map.getView().setCenter(newCenter);
  to_map.getView().setZoom(zoom);
}



var mapLinked = false;
function toggleJoinLinks() {
  //TODO change the icon
  if (mapLinked === true) {
    mapLinked = false;
    document.getElementById('link-map-button').className = 'link-map-button-off';
  } else {
    mapLinked = true;
    document.getElementById('link-map-button').className = 'link-map-button-on';
  }
  if (mapLinked === true) {
    from_map.on("moveend", moveEnd);
    to_map.on("moveend", moveEnd);
    from_map.on("movestart", moveStart);
    to_map.on("movestart", moveStart);
  } else {
    from_map.un("moveend", moveEnd);
    to_map.un("moveend", moveEnd);
    from_map.un("movestart", moveStart);
    to_map.un("movestart", moveStart);
  }
}

var moving = false;
var origXYZ = new Object();

function moveEnd(e) {
  if (moving) {
      return;
  }
  if (!origXYZ.lonlat){
    return;
  }

  moving = true;
  var passiveMap;
  var activeMap;
  if (e.map == from_map){
    activeMap = from_map;
    passiveMap = to_map;
  } else {
    activeMap = to_map;
    passiveMap = from_map;
  }
  var newZoom = passiveMap.getView().getZoom();
  if (origXYZ.zoom != activeMap.getView().getZoom()) {
    diffzoom = origXYZ.zoom - activeMap.getView().getZoom();
    newZoom = passiveMap.getView().getZoom() - diffzoom;
  }
  var origPixel = activeMap.getPixelFromCoordinate(origXYZ.lonlat);
  var newPixel = activeMap.getPixelFromCoordinate(activeMap.getView().getCenter());
  var difx = origPixel[0] - newPixel[0];
  var dify = origPixel[1] - newPixel[1];
  var passCen = passiveMap.getPixelFromCoordinate(passiveMap.getView().getCenter());
 
  passiveMap.getView().setCenter(passiveMap.getCoordinateFromPixel([passCen[0] - difx, passCen[1] - dify]));
  passiveMap.getView().setZoom(newZoom);

  moving = false;
}


function moveStart(e) {
  var passiveMap;
  var activeMap;
  if (e.map == from_map){
    activeMap = from_map;
    passiveMap = to_map;
  } else {
    activeMap = to_map;
    passiveMap = from_map;
  }
  var cent = activeMap.getView().getCenter();
  origXYZ.lonlat = cent;
  origXYZ.zoom = activeMap.getView().getZoom();
}


function update_gcp_field(gcp_id, elem) {
  var id = gcp_id;
  var value = elem.value;
  var attrib = elem.id.substring(0, (elem.id.length - (id + "").length));
  var url = gcp_update_field_url + "/" + id;

  jQuery('#spinner').show();
  gcp_notice(I18n["warp"]["gcp_updating"]);

  var request = jQuery.ajax({
    type: "PUT",
    url: url,
    data: {authenticity_token: encodeURIComponent(window._token), attribute: attrib, value: value}}
  ).success(function() {
    gcp_notice(I18n["warp"]["gcp_updated"]);
    move_map_markers(gcp_id, elem);
  }).done(function() {
    jQuery('#spinner').hide();
  }).fail(function() {
    gcp_notice(I18n["warp"]["gcp_failed"]);
    elem.value = value;
  });
}

function update_gcp(gcp_id, listele) {
  var id = gcp_id;
  var url = gcp_update_url + "/" + id;

  for (i = 0; i < listele.childNodes.length; i++) {
    listtd = listele.childNodes[i]; //td
    for (e = 0; e < listtd.childNodes.length; e++) {

      listItem = listtd.childNodes[e];//input
     
      if (listItem.id == "x" + gcp_id) {
        x = listItem.value;
      }
      if (listItem.id == "y" + gcp_id) {
        y = listItem.value;
      }
      if (listItem.id == "lon" + gcp_id) {
        lon = listItem.value;
      }
      if (listItem.id == "lat" + gcp_id) {
        lat = listItem.value;
      }

    }
  }
 
  gcp_notice(I18n["warp"]["gcp_updating"]);
  jQuery('#spinner').show();
  
  var request = jQuery.ajax({
    type: "PUT",
    url: url,
    data: {authenticity_token: encodeURIComponent(window._token), x: x, y: y, lon: lon, lat: lat}}
  ).success(function() {
    gcp_notice(I18n["warp"]["gcp_updated"]);
  }).done(function() {
    jQuery('#spinner').hide();
  }).fail(function() {
    gcp_notice(I18n["warp"]["gcp_failed"]);
    elem.value = value;
  });

}


function move_map_markers(gcp_id, elem) {
  var avalue = elem.value;
  var attrib = elem.id;
  trele = elem.parentNode.parentNode; //input>td>tr
  //get the other siblings next door to this one.
  for (i = 0; i < trele.childNodes.length; i++) {
    trchild = trele.childNodes[i]; //tds
    for (e = 0; e < trchild.childNodes.length; e++) {

      inp = trchild.childNodes[e]; //inputs
      if (inp.id == 'x' + gcp_id) {
        x = inp.value;
      }
      if (inp.id == 'y' + gcp_id) {
        y = image_height - inp.value;
      }
      if (inp.id == 'lon' + gcp_id) {
        tlon = inp.value;
      }
      if (inp.id == 'lat' + gcp_id) {
        tlat = inp.value;
      }
    }
  }

  if (attrib == 'x' + gcp_id || attrib == 'y' + gcp_id) {
    var frommark;
    for (var a = 0; a < from_vectors.getSource().getFeatures().length; a++) {
      if (from_vectors.getSource().getFeatures()[a].gcp_id == gcp_id) {
        frommark = from_vectors.getSource().getFeatures()[a];
      }//if
    } //for
    if (attrib == 'x' + gcp_id) {
      x = avalue;
    }
    if (attrib == 'y' + gcp_id) {
      y = image_height - avalue;
    }
     frommark.getGeometry().setCoordinates([x, y]);
  }

  else if (attrib == 'lon' + gcp_id || attrib == 'lat' + gcp_id) {
    var tomark;
    for (var b = 0; b < to_vectors.getSource().getFeatures().length; b++) {
      if (to_vectors.getSource().getFeatures()[b].gcp_id == gcp_id) {
        tomark = to_vectors.getSource().getFeatures()[b];
      } //if
    }//for
    if (attrib == 'lon' + gcp_id) {
      tlon = avalue;
    }
    if (attrib == 'lat' + gcp_id) {
      tlat = avalue;
    }

    hacklonlat = ol.proj.transform([tlon, tlat],'EPSG:4326', 'EPSG:3857');
    tomark.getGeometry().setCoordinates(hacklonlat);
  }
}


var customId = 10000;
function setupLayerSelect() {
  jQuery('.layer-select').select2({
    ajax: {
      url: "/search.json",
      dataType: 'json',
      delay: 250,
      transport: function (params, success, failure) {
        if (params.data && params.data.query.indexOf("http") === 0) {
          var title = params.data.query;
          customId = customId + 1
          var id = customId;
          jQuery('.layer-select').data('select2').dataAdapter.select({"id": id, "type": "Custom", "title": title, "description": "", "href": params.data.query, "thumb": "/uploads/6/thumb/NYC1776-mod.png", "tiles": params.data.query, "year": null})
          return null;
        } else {
          $request = jQuery.ajax(params);
          $request.then(success);
          $request.fail(failure);

          return $request;
        }
      },
      data: function (params) {
        return {
          query: params.term
        };

      },
      processResults: function (data, params) {
        params.page = params.page || 1;

        return {
          results: data.data,
          pagination: {
            more: (params.page * 50) < data.total_count
          }
        };

      },
      cache: true
    },
    escapeMarkup: function (markup) {
      return markup;
    },
    allowClear: true,
    minimumInputLength: 3,
    templateResult: formatItems,
    templateSelection: formatItemSelection
  });

  function formatItems(item) {
    if (item.loading)
      return item.title;
    
    var itemType = getItemType(item);
    var markup = "<div class='select2-result-item clearfix'>" +
            "<div class='select2-result-item__thumb'><img src='" + item.thumb + "' /></div>" +
            "<div class='select2-result-item__meta'>" +
            "<div class='select2-result-item__title'><span class='select2-result-item__type'>" + itemType + ":</span> " + item.title + "</div>";

    if (item.year) {
      markup += "<div class='select2-result-item__year'>"+ I18n['warp']['custom_layer_year'] +": " + item.year + "</div>";
    }

    markup += "</div></div>";

    return markup;
  }

  function formatItemSelection(item) {
    var itemType = getItemType(item); 
    if (item.id === "") {
      return item.text; //placeholder text
    } else {
      return itemType + ": " + item.title;
    }
  }
  
  function getItemType(item){
    var itemType = "";
    if (item.type === "Map"){
      itemType = I18n['warp']['custom_map_type'];
    } else if (item.type === "Layer") {
      itemType = I18n['warp']['custom_layer_type'];
    } else {
      itemType = I18n['warp']['custom_custom_type']
    }
    
    return itemType;
  }



}
