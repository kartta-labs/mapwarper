var un_bounds;
var clipmap;
var vectorSource;

drawPolygonControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'crop-draw-poly-button';
  var element = document.createElement('div');
  element.title = "Add or Modify shapes";
  element.className = 'crop-draw-poly ol-unselectable ol-control ol-active';
  element.appendChild(button);

  var drawPolygon = function(e) {
    options.modify.setActive(true);
    options.draw.setActive(true)

    options.select.setActive(false); 
  };

  button.addEventListener('click', drawPolygon, false);

  options.modify.on("change:active", function(e){
    if (e.oldValue == false){
      element.classList.add("ol-active")
    } else {
      element.classList.remove("ol-active")
    }
  })

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) drawPolygonControl.prototype = ol.control.Control;
drawPolygonControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
drawPolygonControl.prototype.constructor = drawPolygonControl;

deletePolygonControl = function(opts) {
  var options = opts || {};

  var button = document.createElement('button');
  button.className  = 'crop-del-poly-button';
  var element = document.createElement('div');
  element.className = 'crop-del-poly ol-unselectable ol-control';
  element.title ="Delete this shape";
  element.appendChild(button);


  var deletePolygon = function(e) {
    options.modify.setActive(false);
    options.draw.setActive(false)

    options.select.setActive(true); 
  };

  button.addEventListener('click', deletePolygon, false);

  options.select.on("change:active", function(e){
    if (e.oldValue == false){
      element.classList.add("ol-active")
    } else {
      element.classList.remove("ol-active")
    }
  })

  ol.control.Control.call(this, {
    element: element,
    target: options.target
  });
};

if ( ol.control.Control ) deletePolygonControl.prototype = ol.control.Control;
deletePolygonControl.prototype = Object.create( ol.control.Control && ol.control.Control.prototype );
deletePolygonControl.prototype.constructor = deletePolygonControl;

function clip_init() {
  var iw = clip_image_width ;
  var ih = clip_image_height ;
  un_bounds =  [0, 0, iw, ih];
  var extent = un_bounds;

  if (typeof (clipmap) == 'undefined') {
    var projection = new ol.proj.Projection({
      code: 'EPSG:32663',
      units: 'm'
    });
    var layers = [
      new ol.layer.Tile({
        source: new ol.source.TileWMS({
          extent: extent,
          url: clip_wms_url,
          projection:  projection,
          params: {'FORMAT': 'image/png', 'STATUS': 'unwarped', 'SRS':'epsg:4326'}
        })
      })
    ];
    var url ="";
    if (mask_exists) {
      url = mask_url;
      vectorSource = new ol.source.Vector({
        url: url,
        projection: 'EPSG:32663',
        format: new ol.format.GeoJSON()
      });
    } else {
        vectorSource = new ol.source.Vector({
          projection: 'EPSG:32663',
          format: new ol.format.GeoJSON()
        });
    }



    var vertexStyle = new ol.style.Style({
      image: new  ol.style.Circle({
        radius: 4,
        fill: new ol.style.Fill({
          color: 'orange'
        })
      }),
      geometry: function(feature) {
        var coords = feature.getGeometry().getCoordinates()[0];
        return new ol.geom.MultiPoint(coords);
      }
    });


    var vectorLayer = new ol.layer.Vector({
      source: vectorSource,
      style: [new ol.style.Style({
        fill: new ol.style.Fill({
          color: 'rgba(238,153,0,0.4)'
        }),
        stroke: new ol.style.Stroke({
          color: '#ee9900',
          width: 2
        }),
        image: new ol.style.Circle({
          radius: 7,
          fill: new ol.style.Fill({
            color: '#ee9900'
          })
        })
      }), 
      vertexStyle]
    });

    var drawingStyle = new ol.style.Style({
      fill: new ol.style.Fill({
        color: 'rgba(0,0,255, 0.4)'
      }),
      stroke: new ol.style.Stroke({
        color: 'blue',
        width: 2
      }),
      image: new ol.style.Circle({
        radius: 7,
        fill: new ol.style.Fill({
          color: 'orange'
        })
      })
    });

    var deletePolygon = function (e) {
      if (e.selected) {
        var c = confirm(I18n["clip"]["confirm_delete_tool"]);
        if (c === true) {
          vectorSource.removeFeature(e.selected[0]);
        }
        select.getFeatures().remove(e.selected[0]);
      }
    }

    var select = new ol.interaction.Select({
      source: vectorSource
    });
    select.setActive(false);
    select.on('select', function(e) {
      deletePolygon(e);
    });

    var modify = new ol.interaction.Modify({
      source: vectorSource,
      pixelTolerance: 20,
      style: drawingStyle
    });

    var draw = new ol.interaction.Draw({
      source: vectorSource,
      type: 'Polygon'
    });

    //deletes the vertex under the pointer. or the created draft when user presses the DELETE key (like ol2 behaviour)
    document.addEventListener('keydown', function(event) {
      if (event.key === "Delete") {
        modify.removePoint();
        draw.removeLastPoint()
      }
    });


    clipmap = new ol.Map({
      layers: layers,
      target: 'clipmap',
      controls: ol.control.defaults().extend([
        new deletePolygonControl({source: vectorSource, select: select,  modify: modify, draw: draw}),
        new drawPolygonControl({source: vectorSource, select: select,  modify: modify, draw: draw})
      ]),
      view: new ol.View({
        center: ol.extent.getCenter(extent),
        minZoom: -4,
        maxZoom: 6,
        maxResolution: 10.496,
        projection: projection
      })
    });
    clipmap.getView().fit(extent, clipmap.getSize());
  
    clipmap.addInteraction(modify);
    clipmap.addInteraction(draw);
    clipmap.addInteraction(select);

    clipmap.addLayer(vectorLayer);


  }



};

function destroyMask() {
  vectorSource.clear();
}

function serialize_features() {
  var gf = new ol.format.GeoJSON();
  var geojson = gf.writeFeatures(vectorSource.getFeatures());
  document.getElementById('output').value = geojson;
}

function updateOtherMaps() {
  if (typeof to_map != 'undefined' && typeof warped_layer != 'undefined') {
    warped_layer.mergeNewParams({
      'random': Math.random()
    });
    warped_layer.redraw(true);
  }
  if (typeof warpedmap != 'undefined' && typeof warped_wmslayer != 'undefined') {
    warped_wmslayer.getSource().updateParams({'random': Math.random()})
  }
}
