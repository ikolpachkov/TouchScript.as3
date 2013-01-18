package ru.interactivelab.touchscript.inputSources {
	import flash.display.Stage;
	import flash.events.TouchEvent;
	import flash.geom.Point;
	import flash.ui.Multitouch;
	import flash.ui.MultitouchInputMode;
	import flash.utils.Dictionary;

	public class WMTouchInput extends InputSource {
		
		private var _stage:Stage;
		private var _cursorToInternalId:Dictionary = new Dictionary();
		
		public function WMTouchInput(stage:Stage) {
			super();
			_stage = stage;
			
			Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
			
			_stage.addEventListener(TouchEvent.TOUCH_BEGIN, handler_touchBegin);
			_stage.addEventListener(TouchEvent.TOUCH_END, handler_touchEnd);
			_stage.addEventListener(TouchEvent.TOUCH_MOVE, handler_touchMove);
		}
		
		private function handler_touchBegin(event:TouchEvent):void {
			if (_cursorToInternalId[event.touchPointID] != undefined) return;
			_cursorToInternalId[event.touchPointID] = beginTouch(new Point(event.stageX, event.stageY));
		}
		
		private function handler_touchEnd(event:TouchEvent):void {
			if (_cursorToInternalId[event.touchPointID] == undefined) return;
			endTouch(_cursorToInternalId[event.touchPointID]);
			delete _cursorToInternalId[event.touchPointID];
		}
		
		private function handler_touchMove(event:TouchEvent):void {
			if (_cursorToInternalId[event.touchPointID] == undefined) return;
			moveTouch(_cursorToInternalId[event.touchPointID], new Point(event.stageX, event.stageY));

		}
	}
}