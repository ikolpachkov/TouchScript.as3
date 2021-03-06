/*
* Copyright (C) 2013 Interactive Lab
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
* files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
* modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
* Software is furnished to do so, subject to the following conditions:
* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the 
* Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
* WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
* COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
* OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package ru.interactivelab.touchscript {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.InteractiveObject;
	import flash.display.Stage;
	import flash.errors.IllegalOperationError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Point;
	import flash.utils.Dictionary;
	
	import ru.interactivelab.touchscript.events.TouchManagerEvent;
	import ru.interactivelab.touchscript.gestures.Gesture;
	import ru.interactivelab.touchscript.gestures.GestureState;
	import ru.interactivelab.touchscript.math.Vector2;
	import ru.interactivelab.touchscript.utils.DisplayObjectUtils;
	import ru.interactivelab.touchscript.utils.Time;
	import ru.valyard.behaviors.behaviors;

	use namespace touch_internal;
	
	public class TouchManagerImpl extends EventDispatcher {
		
		public static const CM_TO_INCH:Number					= 0.393700787;
		public static const INCH_TO_CM:Number					= 1/CM_TO_INCH;
		
		private var _dpi:Number = 72;
		private var _touchRadius:Number = .75;
		private var _initialized:Boolean = false;
		
		private var _stage:Stage;
		private var _touches:Array = [];
		private var _idToTouch:Dictionary = new Dictionary();
		private var _touchesBegan:Array = [];
		private var _touchesEnded:Array = [];
		private var _touchesCancelled:Array = [];
		private var _touchesMoved:Dictionary = new Dictionary();
		private var _gesturesToReset:Array = [];
		private var _nextTouchPointId:int = 0;
		
		private var _tmpPoint:Point = new Point();
		
		//--------------------------------------------------------------------------
		//
		// Properties
		//
		//--------------------------------------------------------------------------
		
		public function get dpi():Number {
			return _dpi;
		}
		
		public function set dpi(value:Number):void {
			_dpi = value;
		}
		
		public function get touchRadius():Number {
			return _touchRadius;
		}
		
		public function set touchRadius(value:Number):void {
			_touchRadius = value;
		}
		
		public function get pixelTouchRadius():Number {
			return _touchRadius * dotsPerCentimeter;
		}
		
		public function get dotsPerCentimeter():Number {
			return CM_TO_INCH * _dpi;
		}
		
		public function get touchesCount():int {
			return _touches.length;
		}
		
		public function get touches():Array {
			return _touches.concat();
		}
		
		//--------------------------------------------------------------------------
		//
		// Constructor
		//
		//--------------------------------------------------------------------------
		
		public function TouchManagerImpl() {
			Time.addEventListener(Event.ENTER_FRAME, update, false, -100);
		}
		
		//--------------------------------------------------------------------------
		//
		// Public methods
		//
		//--------------------------------------------------------------------------
		
		public function init(stage:Stage):void {
			_initialized = true;
			_stage = stage;
		}
		
		public function getHitTarget(x:Number, y:Number):InteractiveObject {
			if (!_initialized) initError();
			_tmpPoint.x = x;
			_tmpPoint.y = y;
			var target:InteractiveObject = DisplayObjectUtils.getTopTarget(_stage, _tmpPoint);
			// TODO: HitTests
			return target;
		}
		
		public function beginTouch(position:Vector2):int {
			var touch:TouchPoint = new TouchPoint(_nextTouchPointId++, position);
			_touchesBegan.push(touch);
			return touch.$id;
		}
		
		public function endTouch(id:int):void {
			var touch:TouchPoint;
			if (_idToTouch[id]) {
				touch = _idToTouch[id];
			} else {
				for each (var added:TouchPoint in _touchesBegan) {
					if (added.$id == id) {
						touch = added;
						break;
					}
				}
				if (touch == null) return;
			}
			_touchesEnded.push(touch);
		}
		
		public function cancelTouch(id:int):void {
			var touch:TouchPoint;
			if (_idToTouch[id]) {
				touch = _idToTouch[id];
			} else {
				for each (var added:TouchPoint in _touchesBegan) {
					if (added.$id == id) {
						touch = added;
						break;
					}
				}
				if (touch == null) return;
			}
			_touchesCancelled.push(touch);
		}
		
		public function moveTouch(id:int, position:Vector2):void {
			_touchesMoved[id] = position;
		}
		
		//--------------------------------------------------------------------------
		//
		// Internal methods
		//
		//--------------------------------------------------------------------------
		
		touch_internal function $gestureChangeState(gesture:Gesture, state:String):String {
			switch (state) {
				case GestureState.POSSIBLE:
					break;
				case GestureState.BEGAN:
					switch (gesture.state) {
						case GestureState.POSSIBLE:
							break;
						default:
							stateError(gesture, state);
							break;
					}
					if (gestureCanRecognize(gesture)) {
						recognizeGesture(gesture);
					} else {
						addToReset(gesture);
						return GestureState.FAILED;
					}
					break;
				case GestureState.CHANGED:
					switch (gesture.state) {
						case GestureState.BEGAN:
						case GestureState.CHANGED:
							break;
						default:
							stateError(gesture, state);
							break;
					}
					break;
				case GestureState.FAILED:
					addToReset(gesture);
					break;
				case GestureState.RECOGNIZED:
					addToReset(gesture);
					switch (gesture.state) {
						case GestureState.POSSIBLE:
							if (gestureCanRecognize(gesture)) {
								recognizeGesture(gesture);
							} else {
								return GestureState.FAILED;
							}
							break;
						case GestureState.BEGAN:
						case GestureState.CHANGED:
							break;
						default:
							stateError(gesture, state);
							break;
					}
					break;
				case GestureState.CANCELLED:
					addToReset(gesture);
					break;
			}
			
			return state;
		}
		
		touch_internal function $ignoreTouch(touch:TouchPoint):void {}
		
		//--------------------------------------------------------------------------
		//
		// Private functions
		//
		//--------------------------------------------------------------------------
		
		private function updateBegan():Boolean {
			if (_touchesBegan.length > 0) {
				var targetTouches:Dictionary = new Dictionary();
				for each (var touch:TouchPoint in _touchesBegan) {
					_touches.push(touch);
					_idToTouch[touch.$id] = touch;
					touch.$target = getHitTarget(touch.$position.$x, touch.$position.$y);
					
					if (touch.$target != null) {
						var list:Array = targetTouches[touch.$target];
						if (!list) {
							list = [];
							targetTouches[touch.$target] = list;
						}
						list.push(touch);
					}
				}
				
				// get touches per gesture
				// touches can come to a gesture from multiple targets in hierarchy
				var gestureTouches:Dictionary = new Dictionary();
				var activeGestures:Array = []; // no order in a Dictionary
				for (var t:Object in targetTouches) {
					var target:InteractiveObject = t as InteractiveObject;
					var mightBeActiveGestures:Array = getHierarchyContaining(target);
					var possibleGestures:Array = getHierarchyEndingWith(target);
					
					for each (var gesture:Gesture in possibleGestures) {
						if (!gestureIsActive(gesture)) continue;
						
						var canReceiveTouches:Boolean = true;
						for each (var activeGesture:Gesture in mightBeActiveGestures) {
							if (gesture == activeGesture) continue;
							if ((activeGesture.state == GestureState.BEGAN || activeGesture.state == GestureState.CHANGED) && (activeGesture.canPreventGesture(gesture))) {
								canReceiveTouches = false;
								break;
							}
						}
						if (canReceiveTouches) {
							var touchesToReceive:Array = [];
							for each (touch in targetTouches[target]) {
								if (gesture.shouldReceiveTouch(touch)) touchesToReceive.push(touch);
							}
							if (touchesToReceive.length > 0) {
								if (gestureTouches[gesture]) {
									gestureTouches[gesture] = (gestureTouches[gesture] as Array).concat(touchesToReceive);
								} else {
									activeGestures.push(gesture);
									gestureTouches[gesture] = touchesToReceive;
								}
							}
						}
					}
				}
				
				for each (gesture in activeGestures) {
					if (gestureIsActive(gesture)) gesture.$touchesBegan(gestureTouches[gesture]);
				}
				if (hasEventListener(TouchManagerEvent.TOUCH_POINTS_ADDED)) 
					dispatchEvent(new TouchManagerEvent(TouchManagerEvent.TOUCH_POINTS_ADDED, false, false, _touchesBegan));
				_touchesBegan.length = 0;
				
				return true;
			}
			return false;			
		}
		
		private function updateMoved():Boolean {
			var targetTouches:Dictionary = new Dictionary();
			var reallyMoved:Array = [];
			
			for each (var touch:TouchPoint in _touches) {
				var position:Vector2 = _touchesMoved[touch.$id];
				if (position && !touch.position.equals(position)) {
					touch.position = position;
					reallyMoved.push(touch);
					if (touch.$target != null) {
						var list:Array = targetTouches[touch.$target];
						if (!list) {
							list = [];
							targetTouches[touch.$target] = list;
						}
						list.push(touch);
					}
				} else {
					touch.position = touch.$position;
				}
			}
			
			if (reallyMoved.length) {
				var gestureTouches:Dictionary = new Dictionary();
				var activeGestures:Array = []; // no order in a Dictionary
				for (var t:Object in targetTouches) {
					var target:InteractiveObject = t as InteractiveObject;
					var possibleGestures:Array = getHierarchyEndingWith(target);
					for each (var gesture:Gesture in possibleGestures) {
						if (!gestureIsActive(gesture)) continue;
						
						var touchesToReceive:Array = [];
						for each (touch in targetTouches[target]) {
							if (gesture.hasTouchPoint(touch)) touchesToReceive.push(touch);
						}
						if (touchesToReceive.length > 0) {
							if (gestureTouches[gesture]) {
								gestureTouches[gesture] = (gestureTouches[gesture] as Array).concat(touchesToReceive);
							} else {
								activeGestures.push(gesture);
								gestureTouches[gesture] = touchesToReceive;
							}
						}
					}
				}
				
				for each (gesture in activeGestures) {
					if (gestureIsActive(gesture)) gesture.$touchesMoved(gestureTouches[gesture]);
				}
				if (hasEventListener(TouchManagerEvent.TOUCH_POINTS_UPDATED)) 
					dispatchEvent(new TouchManagerEvent(TouchManagerEvent.TOUCH_POINTS_UPDATED, false, false, reallyMoved));
			}
			
			_touchesMoved = new Dictionary();
			
			return reallyMoved.length > 0;
		}
		
		private function updateEnded():Boolean {
			if (_touchesEnded.length > 0) {
				var targetTouches:Dictionary = new Dictionary();
				for each (var touch:TouchPoint in _touchesEnded) {
					_touches.splice(_touches.indexOf(touch), 1);
					delete _idToTouch[touch.$id];
					
					if (touch.$target != null) {
						var list:Array = targetTouches[touch.$target];
						if (!list) {
							list = [];
							targetTouches[touch.$target] = list;
						}
						list.push(touch);
					}
				}
				
				var gestureTouches:Dictionary = new Dictionary();
				var activeGestures:Array = []; // no order in a Dictionary
				for (var t:Object in targetTouches) {
					var target:InteractiveObject = t as InteractiveObject;
					var possibleGestures:Array = getHierarchyEndingWith(target);
					for each (var gesture:Gesture in possibleGestures) {
						if (!gestureIsActive(gesture)) continue;
						
						var touchesToReceive:Array = [];
						for each (touch in targetTouches[target]) {
							if (gesture.hasTouchPoint(touch)) touchesToReceive.push(touch);
						}
						if (touchesToReceive.length > 0) {
							if (gestureTouches[gesture]) {
								gestureTouches[gesture] = (gestureTouches[gesture] as Array).concat(touchesToReceive);
							} else {
								activeGestures.push(gesture);
								gestureTouches[gesture] = touchesToReceive;
							}
						}
					}
				}
				
				for each (gesture in activeGestures) {
					if (gestureIsActive(gesture)) gesture.$touchesEnded(gestureTouches[gesture]);
				}
				if (hasEventListener(TouchManagerEvent.TOUCH_POINTS_REMOVED)) 
					dispatchEvent(new TouchManagerEvent(TouchManagerEvent.TOUCH_POINTS_REMOVED, false, false, _touchesEnded));
				_touchesEnded.length = 0;
				
				return true;
			}
			return false;
		}
		
		private function updateCancelled():Boolean {
			if (_touchesCancelled.length > 0) {
				var targetTouches:Dictionary = new Dictionary();
				for each (var touch:TouchPoint in _touchesCancelled) {
					_touches.splice(_touches.indexOf(touch), 1);
					delete _idToTouch[touch.$id];
					
					if (touch.$target != null) {
						var list:Array = targetTouches[touch.$target];
						if (!list) {
							list = [];
							targetTouches[touch.$target] = list;
						}
						list.push(touch);
					}
				}
				
				var gestureTouches:Dictionary = new Dictionary();
				var activeGestures:Array = []; // no order in a Dictionary
				for (var t:Object in targetTouches) {
					var target:InteractiveObject = t as InteractiveObject;
					var possibleGestures:Array = getHierarchyEndingWith(target);
					for each (var gesture:Gesture in possibleGestures) {
						if (!gestureIsActive(gesture)) continue;
						
						var touchesToReceive:Array = [];
						for each (touch in targetTouches[target]) {
							if (gesture.hasTouchPoint(touch)) touchesToReceive.push(touch);
						}
						if (touchesToReceive.length > 0) {
							if (gestureTouches[gesture]) {
								gestureTouches[gesture] = (gestureTouches[gesture] as Array).concat(touchesToReceive);
							} else {
								activeGestures.push(gesture);
								gestureTouches[gesture] = touchesToReceive;
							}
						}
					}
				}
				
				for each (gesture in activeGestures) {
					if (gestureIsActive(gesture)) gesture.$touchesCancelled(gestureTouches[gesture]);
				}
				if (hasEventListener(TouchManagerEvent.TOUCH_POINTS_CANCELLED)) 
					dispatchEvent(new TouchManagerEvent(TouchManagerEvent.TOUCH_POINTS_CANCELLED, false, false, _touchesCancelled));
				_touchesCancelled.length = 0;
				
				return true;
			}
			return false;
		}
		
		private function update(event:Event = null):void {
			// reset gestures changed between update loops
			resetGestures();
			var updated:Boolean = updateBegan();
			updated = updateMoved() || updated;
			updated = updateEnded() || updated;
			updated = updateCancelled() || updated;
			if (updated) resetGestures();
		}
		
		private function resetGestures():void {
			for each (var gesture:Gesture in _gesturesToReset) {
				gesture.$reset();
				gesture.$setState(GestureState.POSSIBLE);
			}
			_gesturesToReset.length = 0;
		}
		
		private function getHierarchyEndingWith(target:InteractiveObject):Array {
			var hierarchy:Array = [];
			while (target != null) {
				hierarchy = hierarchy.concat(getEnabledGesturesOnTarget(target));
				target = target.parent;
			}
			return hierarchy;
		}
		
		private function getHierarchyBeginningWith(target:InteractiveObject, includeSelf:Boolean = true):Array {
			var hierarchy:Array = [];
			if (includeSelf) hierarchy = hierarchy.concat(getEnabledGesturesOnTarget(target));
			if (target is DisplayObjectContainer) {
				var doc:DisplayObjectContainer = target as DisplayObjectContainer;
				for (var i:int = 0; i < doc.numChildren; i++) {
					var child:InteractiveObject = doc.getChildAt(i) as InteractiveObject;
					if (!child) continue;
					hierarchy = hierarchy.concat(getHierarchyBeginningWith(child));
				}
			}
			return hierarchy;
		}
		
		private function getHierarchyContaining(target:InteractiveObject):Array {
			var hierarchy:Array = getHierarchyEndingWith(target);
			return hierarchy.concat(getHierarchyBeginningWith(target, false));
		}
		
		private function getEnabledGesturesOnTarget(target:InteractiveObject):Array {
			return behaviors(target).getAll(Gesture);			
		}
		
		private function gestureIsActive(gesture:Gesture):Boolean {
			switch (gesture.state) {
				case GestureState.FAILED:
				case GestureState.RECOGNIZED:
				case GestureState.CANCELLED:
					return false;
				default:
					return true;
			}
		}
		
		private function gestureCanRecognize(gesture:Gesture):Boolean {
			if (!gesture.shouldBegin()) return false;
			var gestures:Array = getHierarchyContaining(gesture.displayTarget);
			for each (var otherGesture:Gesture in gestures) {
				if (gesture == otherGesture) continue;
				if (!gestureIsActive(otherGesture)) continue;
				if ((otherGesture.state == GestureState.BEGAN || otherGesture.state == GestureState.CHANGED) && otherGesture.canPreventGesture(gesture)) {
					return false;
				}
			}
			
			return true;
		}
		
		private function recognizeGesture(gesture:Gesture):void {
			var gestures:Array = getHierarchyContaining(gesture.displayTarget);
			for each (var otherGesture:Gesture in gestures) {
				if (gesture == otherGesture) continue;
				if (!gestureIsActive(otherGesture)) continue;
				if (!(otherGesture.state == GestureState.BEGAN || otherGesture.state == GestureState.CHANGED) && gesture.canPreventGesture(otherGesture)) {
					failGesture(otherGesture);
				}
			}
		}
		
		private function failGesture(gesture:Gesture):void {
			gesture.$setState(GestureState.FAILED);
		}
		
		private function addToReset(gesture:Gesture):void {
			if (_gesturesToReset.indexOf(gesture) == -1) _gesturesToReset.push(gesture);
		}
		
		private function initError():void {
			throw new IllegalOperationError("TouchManager hasn't been initialized!");
		}
		
		private function stateError(gesture:Gesture, state:String):void {
			trace("Gesture", gesture, "erroneously tried to enter state", state, "from state", gesture.state);
		}
		
	}
}