package ru.interactivelab.touchscript.gestures {
	import flash.display.InteractiveObject;
	import flash.geom.Point;
	
	import ru.interactivelab.touchscript.TouchManager;
	import ru.interactivelab.touchscript.TouchPoint;
	import ru.interactivelab.touchscript.clusters.Cluster2;
	import ru.interactivelab.touchscript.math.Consts;
	
	public class RotateGesture extends Transform2DGestureBase {
		
		private var _cluster2:Cluster2 = new Cluster2();
		private var _rotationBuffer:Number = 0;
		private var _isRotating:Boolean = false;
		
		private var _rotationThreshold:Number = 3;
		private var _minClusterDistance:Number = 0.5;
		private var _localDeltaRotation:Number = 0;
		
		public function get rotationThreshold():Number {
			return _rotationThreshold;
		}
		
		public function set rotationThreshold(value:Number):void {
			_rotationThreshold = value;
		}
		
		public function get minClusterDistance():Number {
			return _minClusterDistance;
		}
		
		public function set minClusterDistance(value:Number):void {
			_minClusterDistance = value;
		}
		
		public function get localDeltaRotation():Number {
			return _localDeltaRotation;
		}
		
		public function RotateGesture(target:InteractiveObject, ...params) {
			super(target, params);
		}
		
		protected override function touchesBegan(touches:Array):void {
			super.touchesBegan(touches);
			for each (var touch:TouchPoint in touches) {
				_cluster2.addPoint(touch);
			}
		}
		
		protected override function touchesMoved(touches:Array):void {
			super.touchesMoved(touches);
			
			_cluster2.invalidate();
			_cluster2.minPointsDistance = _minClusterDistance * TouchManager.dotsPerCentimeter;
			
			if (!_cluster2.hasClusters) return;
			
			var deltaRotation:Number = 0;
			var oldPos1:Point = _cluster2.getPreviousCenterPosition(Cluster2.CLUSTER1);
			var oldPos2:Point = _cluster2.getPreviousCenterPosition(Cluster2.CLUSTER2);
			var newPos1:Point = _cluster2.getCenterPosition(Cluster2.CLUSTER1);
			var newPos2:Point = _cluster2.getCenterPosition(Cluster2.CLUSTER2);
			var oldCenterPos:Point = new Point((oldPos1.x + oldPos2.x) * .5, (oldPos1.y + oldPos2.y) * .5);
			var newCenterPos:Point = new Point((newPos1.x + newPos2.x) * .5, (newPos1.y + newPos2.y) * .5);
			var oldVector:Point = oldPos2.subtract(oldPos1);
			var newVector:Point = newPos2.subtract(newPos1);
			
			var angle:Number = Math.acos((newVector.x*oldVector.x + newVector.y*oldVector.y) / (newVector.length * oldVector.length)) * Consts.RADIANS_TO_DEGREES;
			if (newVector.x * oldVector.y - newVector.y * oldVector.x > 0) angle = -angle; // crossproduct
			
			if (_isRotating) {
				deltaRotation = angle;
			} else {
				_rotationBuffer += angle;
				if (_rotationBuffer * _rotationBuffer >= _rotationThreshold * _rotationThreshold) {
					_isRotating = true;
					deltaRotation = _rotationBuffer;
				}
			}
			
			if (Math.abs(deltaRotation) > 0.00001) {
				switch (state) {
					case GestureState.POSSIBLE:
					case GestureState.BEGAN:
					case GestureState.CHANGED:
						_globalTransformCenter = newCenterPos;
						_localTransformCenter = globalToLocalPosition(_globalTransformCenter);
						_previousGlobalTransformCenter = oldCenterPos;
						_previousLocalTransformCenter = globalToLocalPosition(_previousGlobalTransformCenter);
						
						_localDeltaRotation = deltaRotation;
						
						if (state == GestureState.POSSIBLE) {
							setState(GestureState.BEGAN);
						} else {
							setState(GestureState.CHANGED);
						}
						break;
				}
			}
		}
		
		protected override function touchesEnded(touches:Array):void {
			for each (var touch:TouchPoint in touches) {
				_cluster2.removePoint(touch);
			}
			if (!_cluster2.hasClusters) {
				resetRotation();
			}
			super.touchesEnded(touches);
		}
		
		protected override function reset():void {
			super.reset();
			_cluster2.removeAllPoints();
			resetRotation();
		}
		
		protected override function resetGestureProperties():void {
			super.resetGestureProperties();
			_localDeltaRotation = 0;
		}
		
		private function resetRotation():void {
			_rotationBuffer = 0;
			_isRotating = false;
		}
		
	}
}