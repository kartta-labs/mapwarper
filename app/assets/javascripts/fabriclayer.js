// Adapted from https://github.com/CALIL/ol3fabric/  MIT license
var mapImage;

var FabricLayer
extend = function (child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

FabricLayer = (function (superClass) {
  extend(FabricLayer, superClass);

  FabricLayer.prototype.map = null;

  FabricLayer.prototype.context = null;

  FabricLayer.prototype.canvas = null;

  FabricLayer.prototype.image = null;
  FabricLayer.prototype.mapimage = null;


  function FabricLayer(options) {
    FabricLayer.__super__.constructor.call(this, options);
    this.on('postcompose', this.postcompose_, this);
    this.setSource(new ol.source.Vector());
    this.image = options.image;
    this.opacity = options.opacity;
    this.angle = options.angle;
    this.center = options.center;
    this.scaleX = options.scale;
    this.scaleY = options.scale;
  }

  // FabricLayer.prototype.setAngle = function(rotation) {
  //   this.angle = this.rotationToAngle(rotation);
  //   console.log(this.angle);
  //   return this.changed();
  // };

  // FabricLayer.prototype.rotationToAngle = function(rotation) {
  //   return rotation / Math.PI * 180;
  // };

  FabricLayer.prototype.postcompose_ = function (event) {

    var oneMeterPx, pixelRatio, r, r2, resolutionAtCoords, view;
    if (this.map == null) {
      //console.log("map is null")
      return;
    }
    this.context = event.context;
    pixelRatio = event.frameState.pixelRatio;
    view = this.map.getView();
    resolutionAtCoords = ol.proj.getPointResolution(view.getProjection(), event.frameState.viewState.resolution, view.getCenter());


    //  resolutionAtCoords = view.getProjection().getPointResolution(event.frameState.viewState.resolution, view.getCenter());
    oneMeterPx = (1 / resolutionAtCoords) * pixelRatio;
    r = event.frameState.viewState.rotation;
    r2 = this.rotation * Math.PI / 180;
    if (this.canvas == null) {
      this.map.on('moveend', (function (_this) {
        return function () {
         // console.log('moveend');
          return _this.addFabricObject();
        };
      })(this));
      this.fabricInit();
    }

    return this.canvas.renderAllOnTop();
  };

  FabricLayer.prototype.fabricInit = function () {
    mapEle = document.getElementById("map")

    this.canvas = new fabric.Canvas(this.context.canvas, {
      width: mapEle.clientWidth,
      height: mapEle.clientHeight,
      renderOnAddRemove: true,
      selection: false
    });
  
  //  this.canvas.setWidth(mapEle.clientWidth);
   // this.canvas.setHeight(mapEle.clientHeight);
    
    window.onresize = (function(_this) {
      return function() {
      
       var mapEle = document.getElementById("map");
        _this.canvas.setWidth(mapEle.clientWidth);
        _this.canvas.setHeight(mapEle.clientHeight);
        return true;
      };
    })(this);

    // this.canvas.on('object:selected', (function(_this) {
    //   return function() {
    //     return console.log('object:selected');
    //   };
    // })(this));

    // this.canvas.on('selection:cleared', (function(_this) {
    //   return function() {
    //     return console.log('selection:cleared');
    //   };
    // })(this));


    this.canvas.on('object:modified', (function (_this) {
      return function () {
       // return console.log('object:modified', mapImage);
      };
    })(this));

    fabric.Object.prototype.scaleX = 1;
    fabric.Object.prototype.scaleY = 1;
    fabric.Object.prototype.transparentCorners = false;
    fabric.Object.prototype.cornerColor = "#061a2a";
    fabric.Object.prototype.borderColor = "#061a2a";
    fabric.Object.prototype.lockUniScaling = true;

    fabric.Object.prototype.borderOpacityWhenMoving = 0.8;
    fabric.Object.prototype.cornerSize = 14;
    fabric.Object.prototype.borderScaleFactor = 0.5;
    this.canvas._renderAll = this.canvas.renderAll;
    this.canvas.renderAll = (function (_this) {
      return function () {
        return _this.changed();
      };
    })(this);
    this.canvas._renderTop = this.canvas.renderTop;
    this.canvas.renderTop = (function (_this) {
      return function () {
        return _this.changed();
      };
    })(this);



    var imgc = this.map.getPixelFromCoordinate(this.map.getView().getCenter());

    var imgElement = document.getElementById(this.image);

    if (this.center){
      imgc = this.map.getPixelFromCoordinate(this.center)
    }

    var left = imgc[0];
    var top = imgc[1];
    mapImage = new fabric.Image(imgElement, {
      left: left,
      top: top,
      originX: "center",
      originY: "center",
      angle: this.angle || 0,
      scaleX: this.scaleX || 1,
      scaleY: this.scaleY || 1
    });

    this.mapimage = mapImage;

    var dragPan;
    this.map.getInteractions().forEach(function (interaction, i) {
      if (interaction instanceof ol.interaction.DragPan) {
        dragPan = interaction;
      }
    }, this);


    this.canvas.on('mouse:over', function (e) {
      if (e.target) {
        dragPan.setActive(false);
      }
    });

    this.canvas.on('mouse:out', function (e) {
      if (e.target) {
        dragPan.setActive(true);
      }
    });




    return this.canvas.renderAllOnTop = function () {
      var activeGroup, canvasToDrawOn;
      canvasToDrawOn = this.contextTop;
      activeGroup = this.getActiveGroup();
      
      this.clearContext(this.contextTop);
      this.fire('before:render');
      if (this.clipTo) {
        fabric.util.clipContext(this, canvasToDrawOn);
      }
      this._renderBackground(canvasToDrawOn);
      this._renderObjects(canvasToDrawOn, activeGroup);
      this._renderActiveGroup(canvasToDrawOn, activeGroup);
      if (this.selection && this._groupSelector) {
        this._drawSelection();
      }
      if (this.clipTo) {
        canvasToDrawOn.restore();
      }
      this._renderOverlay(canvasToDrawOn);
      if (this.controlsAboveOverlay && this.interactive) {
        this.drawControls(canvasToDrawOn);
      }
      this.fire('after:render');
      return this;
    };

  };

  FabricLayer.prototype.addFabricObject = function () {

  
    var results = [];

    if (this.canvas.contains(mapImage) == false) {
      this.canvas.clear();
      results.push(this.canvas.add(mapImage));
      mapImage.setOpacity(this.opacity);
      this.canvas.setActiveObject(mapImage)
      this.canvas.bringToFront(mapImage)
    }

    return results;
  };

  return FabricLayer;

})(ol.layer.Vector);
