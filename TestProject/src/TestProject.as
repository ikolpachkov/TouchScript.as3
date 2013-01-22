package {
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.geom.Matrix;
	import flash.geom.Point;
	
	import ru.interactivelab.touchscript.TouchManager;
	import ru.interactivelab.touchscript.debugging.TouchDebugger;
	import ru.interactivelab.touchscript.events.gestures.GestureEvent;
	import ru.interactivelab.touchscript.gestures.FlickGesture;
	import ru.interactivelab.touchscript.gestures.Gesture;
	import ru.interactivelab.touchscript.gestures.GestureState;
	import ru.interactivelab.touchscript.gestures.LongPressGesture;
	import ru.interactivelab.touchscript.gestures.PanGesture;
	import ru.interactivelab.touchscript.gestures.PressGesture;
	import ru.interactivelab.touchscript.gestures.ReleaseGesture;
	import ru.interactivelab.touchscript.gestures.RotateGesture;
	import ru.interactivelab.touchscript.gestures.ScaleGesture;
	import ru.interactivelab.touchscript.gestures.TapGesture;
	import ru.interactivelab.touchscript.inputSources.MouseInput;
	import ru.interactivelab.touchscript.inputSources.TuioInput;
	import ru.interactivelab.touchscript.math.Consts;
	import ru.interactivelab.touchscript.math.Vector2;
	
	import test.Box;
	
	[SWF(frameRate="60", width="1024", height="768")]
	public class TestProject extends Sprite {
		
		public static const MAIN_WINDOW_PADDING:int = 20;
		
		private var _mouseInput:MouseInput;
		private var _tuioInput:TuioInput;
		
		public function TestProject() {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			TouchManager.init(stage);
			_mouseInput = new MouseInput(stage);
			_tuioInput = new TuioInput(stage.stageWidth, stage.stageHeight);
			
			// main window
			var wnd:Box = new Box(stage.stageWidth-MAIN_WINDOW_PADDING*2, stage.stageHeight-MAIN_WINDOW_PADDING*2, 0xEEEEEE);
			wnd.x = wnd.y = MAIN_WINDOW_PADDING;
			addChild(wnd);
			
			var pressGesture:PressGesture = new PressGesture(wnd);
			pressGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_wnd_pressed);
			var releaseGesture:ReleaseGesture = new ReleaseGesture(wnd);
			releaseGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_wnd_released);
			
			// tap hierarchy
			var tap1:Box = new Box(500, 130, randomColor(), "Tap hierarchy example", "top");
			tap1.x = MAIN_WINDOW_PADDING + 10;
			tap1.y = MAIN_WINDOW_PADDING + 10;
			addChild(tap1);
			var tapGesture:TapGesture = new TapGesture(tap1);
			tapGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_tap_tapped);
			
			var tap2a:Box = new Box(220, 80, randomColor());
			tap2a.x = 10;
			tap2a.y = 40;
			tap1.addChild(tap2a);
			tapGesture = new TapGesture(tap2a);
			tapGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_tap_tapped);
			
			var tap2b:Box = new Box(220, 80, randomColor());
			tap2b.x = 500 - 220 - 10;
			tap2b.y = 40;
			tap1.addChild(tap2b);
			tapGesture = new TapGesture(tap2b);
			tapGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_tap_tapped);
			
			var tap3a:Box = new Box(120, 60, randomColor(), "Tap me!");
			tap3a.x = 10;
			tap3a.y = 10;
			tap2a.addChild(tap3a);
			tapGesture = new TapGesture(tap3a);
			tapGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_tap_tapped);
			
			var tap3b:Box = new Box(120, 60, randomColor(), "Tap me!");
			tap3b.x = 10;
			tap3b.y = 10;
			tap2b.addChild(tap3b);
			tapGesture = new TapGesture(tap3b);
			tapGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_tap_tapped);
			
			// longpress hierarchy
			var lp1:Box = new Box(440, 130, randomColor(), "Longpress hierarchy example", "top");
			lp1.x = stage.stageWidth - lp1.width - MAIN_WINDOW_PADDING - 10;
			lp1.y = MAIN_WINDOW_PADDING + 10;
			addChild(lp1);
			var longpressGesture:LongPressGesture = new LongPressGesture(lp1);
			longpressGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_longPressRecognized);
			
			var lp2:Box = new Box(220, 80, randomColor(), "Press and hold me!");
			lp2.x = 10;
			lp2.y = 40;
			lp1.addChild(lp2);
			longpressGesture = new LongPressGesture(lp2);
			longpressGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_longPressRecognized);
			
			// movable/scalable stuff
			var box1:Box = new Box(800, 400, randomColor(), "Scalable container", "top");
			box1.name = "box1";
			box1.x = MAIN_WINDOW_PADDING + 10;
			box1.y = 200;
			addChild(box1);
			var panGesture:PanGesture = new PanGesture(box1);
			panGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_pan);
			var scaleGesture:ScaleGesture = new ScaleGesture(box1);
			scaleGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_scale);
			var rotateGesture:RotateGesture = new RotateGesture(box1);
			rotateGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_rotate);
			panGesture.shouldRecognizeSimultaneouslyWith(scaleGesture, true);
			panGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			scaleGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			
			var box2a:Box = new Box(300, 240, randomColor(), "Drag me");
			box2a.name = "box2a";
			box2a.x = 20
			box2a.y = 50;
			box1.addChild(box2a);
			panGesture = new PanGesture(box2a);
			panGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_pan);
			scaleGesture = new ScaleGesture(box2a);
			scaleGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_scale);
			rotateGesture = new RotateGesture(box2a);
			rotateGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_rotate);
			panGesture.shouldRecognizeSimultaneouslyWith(scaleGesture, true);
			panGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			scaleGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			
			var box2b:Box = new Box(300, 240, randomColor(), "Drag me");
			box2b.name = "box2b";
			box2b.x = 340
			box2b.y = 50;
			box1.addChild(box2b);
			panGesture = new PanGesture(box2b);
			panGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_pan);
			scaleGesture = new ScaleGesture(box2b);
			scaleGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_scale);
			rotateGesture = new RotateGesture(box2b);
			rotateGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_rotate);
			panGesture.shouldRecognizeSimultaneouslyWith(scaleGesture, true);
			panGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			scaleGesture.shouldRecognizeSimultaneouslyWith(rotateGesture, true);
			
			// flick
			var flick1:Box = new Box(200, 100, randomColor(), "Flick me");
			flick1.name = "flick1";
			flick1.x = MAIN_WINDOW_PADDING + 10;
			flick1.y = 640;
			addChild(flick1);
			var flickGesture:FlickGesture = new FlickGesture(flick1);
			flickGesture.addEventListener(GestureEvent.STATE_CHANGED, handler_flick);
			
			addChild(new TouchDebugger());
		}
		
		private function randomColor():uint {
			return 	((Math.random() * 0x80 + 0x80) << 16 ) +
					((Math.random() * 0x80 + 0x80) << 8 ) +
					(Math.random() * 0x80 + 0x80);
		}
		
		private function handler_wnd_pressed(e:GestureEvent):void {
			if (e.state == GestureState.RECOGNIZED) {
				((e.target as Gesture).displayTarget as Box).setColor(0xFFEEEE);
			}
		}
		
		private function handler_wnd_released(e:GestureEvent):void {
			if (e.state == GestureState.RECOGNIZED) {
				((e.target as Gesture).displayTarget as Box).resetColor();
			}
		}
		
		private function handler_tap_tapped(e:GestureEvent):void {
			if (e.state == GestureState.RECOGNIZED) {
				((e.target as Gesture).displayTarget as Box).setColor(randomColor());
			}
		}
		
		private function handler_longPressRecognized(e:GestureEvent):void {
			if (e.state == GestureState.RECOGNIZED) {
				((e.target as Gesture).displayTarget as Box).setColor(randomColor());
			}
		}
		
		private function handler_pan(e:GestureEvent):void {
			var target:PanGesture = e.target as PanGesture;
			if (e.state == GestureState.BEGAN || e.state == GestureState.CHANGED) {
				var delta:Vector2 = target.localDeltaPosition;
				target.displayTarget.x += delta.x;
				target.displayTarget.y += delta.y;
			}
		}
		
		private function handler_scale(e:GestureEvent):void {
			var target:ScaleGesture = e.target as ScaleGesture;
			if (e.state == GestureState.BEGAN || e.state == GestureState.CHANGED) {
				var matrix:Matrix = target.displayTarget.transform.matrix;
				matrix.translate(-target.localTransformCenter.x, -target.localTransformCenter.y);
				matrix.scale(target.localDeltaScale, target.localDeltaScale);
				matrix.translate(target.localTransformCenter.x, target.localTransformCenter.y);
				target.displayTarget.transform.matrix = matrix;
			}
		}
		
		private function handler_rotate(e:GestureEvent):void {
			var target:RotateGesture = e.target as RotateGesture;
			if (e.state == GestureState.BEGAN || e.state == GestureState.CHANGED) {
				var matrix:Matrix = target.displayTarget.transform.matrix;
				matrix.translate(-target.localTransformCenter.x, -target.localTransformCenter.y);
				matrix.rotate(target.localDeltaRotation * Consts.DEGREES_TO_RADIANS);
				matrix.translate(target.localTransformCenter.x, target.localTransformCenter.y);
				target.displayTarget.transform.matrix = matrix;
			}
		}
		
		private function handler_flick(e:GestureEvent):void {
			if (e.state == GestureState.RECOGNIZED) {
				((e.target as Gesture).displayTarget as Box).setColor(randomColor());
			}
		}
		
	}
}