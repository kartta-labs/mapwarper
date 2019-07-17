/* geosearch.js core generic functions for helping to search for maps
 * or layers using a map
 * see geosearch-map.js and geosearch-layer.js
 * which implements
 * the following functions:
 * replaceMapTable(maps)
 * insertMapTablePagination(total, per, current)
 * addMapToMapLayer(mapitem)
 * onFeatureSelect(feature)
 **/


var searchmap;
var maxOpacity = 1;
var minOpacity = 0.1;
var mapIndexLayer;
var mapIndexSelCtrl;
var selectedFeature;
var firstGo = true;
var popup;
var popupContent;
var selectInteract;
function searchmapinit(){
  jQuery('#loadingDiv').hide();

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

  var base_layers = [ new ol.layer.Group({
    title: 'Base Layer',
    layers: blayers
    })
  ] ;
  var styles = [
    new ol.style.Style({
      stroke: new ol.style.Stroke({
        color: 'blue',
        width: 2
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
      layers:  [mapIndexLayer]
    })
  ];
  
  var layers = base_layers.concat(overlay_layers); 

  searchmap = new ol.Map({
    layers: layers,
    target: 'searchmap',
    view: new ol.View({
      minZoom: 2,
      maxZoom: 20,
      center: ol.extent.getCenter(gs_bounds)
    })
  });

  var layerSwitcher = new ol.control.LayerSwitcher({
    tipLabel: 'Layers' 
  });
  searchmap.addControl(layerSwitcher);

  var extent = ol.proj.transformExtent(gs_bounds, 'EPSG:4326', 'EPSG:3857');
  searchmap.getView().fit(extent, searchmap.getSize()); 

  searchmap.on('moveend', updateSearch);

  //Add popup interaction on map bounding boxes
  var container = document.getElementById('popup');
  popupContent = document.getElementById('popup-content');
  var closer = document.getElementById('popup-closer')
  container.style.visibility = "visible";

  popup = new ol.Overlay({
    id: "popup-overlay",
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

  searchmap.addOverlay(popup);

  searchmap.on('click', function(evt) {
    var feature = searchmap.forEachFeatureAtPixel(evt.pixel,
      function(feature) {
        return feature;
      });
    if (feature) {
      jQuery("tr.minimap-tr").removeClass('highlight');
      var coordinates = evt.coordinate;
      popup.setPosition(coordinates);
      popupContent.innerHTML = getPopupHTML(feature);  
      jQuery("tr#map-row-" + feature.get('mapId')).addClass('highlight');
    } else {
      popup.setPosition(undefined);
      closer.blur();
      
    }
  });

  selectInteract = new ol.interaction.Select({});
  searchmap.addInteraction(selectInteract);

  addClickToTable(); 
  do_search();
}

var currentState;
function updateSearch(){
  var currentTime = (new Date()).valueOf();

  currentState = {tag: currentTime};
  if (!firstGo){
    setTimeout(function() {updateStuff(currentTime); }, 1000);
  } else {
    firstGo = false;
  }
}

function updateStuff(expectedTag){
  if (currentState.tag != expectedTag) {
    return;
  }else {
    do_search();
  }
}

function addClickToTable(){
  jQuery("#searchmap-table tr").click(function(){
    removeAllPopups(searchmap);
    jQuery("tr.minimap-tr").removeClass('highlight');
    jQuery(this).addClass('highlight')
    var mapid = this.id.substring("map-row-".length);
    var feat;
    for (var a=0;a<mapIndexLayer.getSource().getFeatures().length;a++){
      if (mapIndexLayer.getSource().getFeatures()[a].get("mapId") == mapid){
        feat = mapIndexLayer.getSource().getFeatures()[a];
      }
    }

    //highlight map polygon
    selectFeature(feat);
  });
}

function doPlaceSearch(frm){
  var place = frm.place.value;
  var options = { 
    'place': place,
    'format': 'json'
  };

  jQuery.ajax({url: mapBaseURL+'/geosearch', data: options})
  .done(function(resp) {
    doPlaceZoom(resp);
  })
  .fail(function(resp) {
    failMessage(resp);
  })

}
 


function doPlaceZoom(extent){
  var extent_a = extent.map(Number)
  var mercExtent =  ol.proj.transformExtent(extent_a, 'EPSG:4326', 'EPSG:3857');
  searchmap.getView().fit(mercExtent, searchmap.getSize());
}


function do_search(pageNum){
  jQuery('#loadingDiv').show();
  
  if (typeof pageNum == "undefined"){
      pageNum = 1;
    }
    
  var searchmapExtent =  ol.proj.transformExtent(searchmap.getView().calculateExtent(),'EPSG:3857', 'EPSG:4326' );

  var options = {'bbox': searchmapExtent.join(","),
    'format': 'json',
    'page': pageNum,
    'operation': 'within',
    'from': jQuery("#from").val(),
    'to': jQuery("#to").val()};

  jQuery.ajax({url: mapBaseURL+'/geosearch', data: options})
  .done(function(resp) {
    loadItems(resp);
  })
  .fail(function(resp) {
    failMessage(resp);
  })

}

function clearMapTable(){
  jQuery("#searchmap-table").empty();
}

function loadItems(resp){
   clearMapTable();
   removeAllPopups(searchmap);

   mapIndexLayer.getSource().clear(true);
   jj = resp;
   smaps = jj.items;
   for (var a=0;a<smaps.length;a++){
    var smap = smaps[a];
     addMapToMapLayer(smap);
   }

  insertMapTablePagination(jj.total_entries, jj.per_page, jj.current_page);
  replaceMapTable(smaps);

  mapIndexLayer.setVisible(true)

  jQuery('#loadingDiv').hide();
}

function failMessage(resp){
  alert(I18n["geosearch"]["search_fail"]);
  jQuery('#loadingDiv').hide();
}

function removeAllPopups(map){
  searchmap.getOverlayById("popup-overlay").setPosition(undefined);
}


function selectFeature(feature){

  var selected_collection = selectInteract.getFeatures();
  selected_collection.clear();
  selected_collection.push(feature);
  selectInteract.dispatchEvent({
    type: 'select',
    selected: [feature],
    deselected: []
  });

  popup.setPosition(ol.extent.getCenter(feature.getGeometry().getExtent()));
  popupContent.innerHTML = getPopupHTML(feature);  
}


