package
{
	import aerys.minko.render.Viewport;
	import aerys.minko.render.effect.SinglePassEffect;
	import aerys.minko.render.effect.SinglePassRenderingEffect;
	import aerys.minko.render.effect.basic.BasicStyle;
	import aerys.minko.render.effect.lighting.LightingEffect;
	import aerys.minko.render.effect.lighting.LightingStyle;
	import aerys.minko.scene.node.Model;
	import aerys.minko.scene.node.camera.FirstPersonCamera;
	import aerys.minko.scene.node.group.LoaderGroup;
	import aerys.minko.scene.node.group.MaterialGroup;
	import aerys.minko.scene.node.group.PickableGroup;
	import aerys.minko.scene.node.group.StyleGroup;
	import aerys.minko.scene.node.group.jiglib.BoxSkinGroup;
	import aerys.minko.scene.node.light.PointLight;
	import aerys.minko.scene.node.mesh.IMesh;
	import aerys.minko.scene.node.mesh.modifier.ColorMeshModifier;
	import aerys.minko.scene.node.mesh.modifier.NormalMeshModifier;
	import aerys.minko.scene.node.mesh.primitive.CubeMesh;
	import aerys.minko.scene.node.texture.ITexture;
	import aerys.minko.scene.visitor.PickingVisitor;
	import aerys.minko.type.enum.TriangleCulling;
	import aerys.minko.type.jiglib.JiglibPhysics;
	import aerys.minko.type.math.Vector4;
	import aerys.monitor.Monitor;
	
	import flash.display.Sprite;
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.ui.Keyboard;
	import flash.utils.getTimer;
	
	import jiglib.cof.JConfig;
	import jiglib.geometry.JPlane;
	
	public class Main extends Sprite
	{
		[Embed("../assets/wall.png")]
		private static const ASSET_WALL_DIFFUSE	: Class;

		private static const PICKING_ENABLED	: Boolean	= true;
		
		private static const CUBE_MESH			: IMesh		= new NormalMeshModifier(CubeMesh.cubeMesh);
		private static const CUBE_TEXTURE		: ITexture	= new LoaderGroup().loadClass(ASSET_WALL_DIFFUSE)[0]
															  as ITexture;
		
		private static const MOUSE_SENSITIVITY	: Number	= .0015;
		private static const WALK_SPEED			: Number	= .5;
		private static const COLORS				: Array		= [0xff0000,
															   0x00ff00,
															   0x0000ff,
															   0xffff00,
															   0x00ffff,
															   0xff00ff];
		private static const SOUNDS				: Array		= [new ImpactPianoMonoC1(),
															   new ImpactPianoMonoC2(),
															   new ImpactPianoMonoC3(),
															   new ImpactPianoMonoC4()];

		private var _viewport	: Viewport			= new Viewport();
		private var _camera		: FirstPersonCamera	= new FirstPersonCamera();
		private var _cubes		: MaterialGroup		= new MaterialGroup(new SinglePassRenderingEffect(new LightCubeShader()), CUBE_TEXTURE);
		private var _light		: PointLight		= new PointLight(0xffffff, .07, 0, 0, new Vector4(0., 10., 0.), 50.);
		private var _scene		: StyleGroup		= new StyleGroup(_camera, _light, _cubes);
	
		private var _speed		: Point				= new Point();
		private var _cursor		: Point				= new Point();
		
		private var _physics	: JiglibPhysics		= new JiglibPhysics(2.);
		
		private var _sound		: SoundChannel		= new SoundChannel();
		
		public function Main()
		{
			if (stage)
				initialize();
			else
				addEventListener(Event.ADDED_TO_STAGE, initialize);
		
			new PU_PickingN().play(0., int.MAX_VALUE, new SoundTransform(.1));
		}
		
		private function initialize(event : Event = null) : void
		{
			removeEventListener(Event.ENTER_FRAME, initialize);
		
			initializeMonitor();
			initializeScene();
			initializePhysics();
			initializeInputs();
			
			stage.frameRate = 60.;
			
			addEventListener(Event.ENTER_FRAME, enterFrameHandler);
		}
		
		private function initializeMonitor() : void
		{
			Monitor.monitor.watch(_viewport, ["renderMode", "renderingTime", "drawingTime", "numTriangles"]);
			Monitor.monitor.visible = false;
			addChild(Monitor.monitor);
		}
		
		private function viewportInitHandler(event : Event) : void
		{
			_viewport.visitors[2] = _viewport.visitors[1];
			_viewport.visitors[1] = new PickingVisitor(5);
		}
		
		private function initializePhysics() : void
		{
			JConfig.solverType = "FAST";
			JConfig.angVelThreshold = 0.05;

			_physics.system.addBody(new JPlane(null, new Vector3D(0., 1., 0., 0.)));
			_physics.system.addBody(new JPlane(null, new Vector3D(0., -1., 0., -100.)));
			_physics.system.addBody(new JPlane(null, new Vector3D(1., 0., 0., -50.)));
			_physics.system.addBody(new JPlane(null, new Vector3D(-1., 0., 0., -50.)));
			_physics.system.addBody(new JPlane(null, new Vector3D(0., 0., 1., -50.)));
			_physics.system.addBody(new JPlane(null, new Vector3D(0., 0., -1., -50.)));
		}
		
		private function initializeScene() : void
		{
			_viewport.antiAliasing = 8.;
			_viewport.defaultEffect = new LightingEffect();
			_viewport.addEventListener(Event.INIT, viewportInitHandler);
			stage.addChild(_viewport);
		
			_camera.position.y = 10.;
			_camera.position.z = -20.;
			_camera.rotation.x = -.3;
			
			initializeWalls();
			initializeCubes();
		}
		
		private function initializeWalls() : void
		{
			var walls	: Model		= new Model(new ColorMeshModifier(CUBE_MESH, Vector.<uint>([0x7f7f7f])));
			
			walls.style.set(BasicStyle.TRIANGLE_CULLING, TriangleCulling.FRONT);
			walls.transform.appendUniformScale(100)
						   .appendTranslation(0., 50., 0.);
		
			_scene.addChild(walls);
		}
		
		private function initializeCubes() : void
		{
			// cubes
			createCube(0x00ff00, 2.5, 2.5, 2.5);
			createCube(0xff0000, 2.5, 2.5, -2.5);
			createCube(0x0000ff, -2.5, 2.5, -2.5);
			createCube(0xffff00, -2.5, 2.5, 2.5);
			
			_scene.style.set(LightingStyle.LIGHTS_ENABLED, 	true);
		}
		
		private function initializeInputs() : void
		{
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
			stage.addEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
		}
		
		private function createCube(color 	: int 		= 0,
									x 		: Number	= NaN,
									y 		: Number	= NaN,
									z 		: Number 	= NaN) : BoxSkinGroup
		{
			// make sure we don't have more thant 12 cubes
			if (_cubes.numChildren == 12)
			{
				_physics.system.removeBody(_cubes[0][0].box);
				_cubes.removeChildAt(0);
			}
			
			var cube 	: LightCube 	= new LightCube(color);
			var pg 		: PickableGroup = new PickableGroup(cube);
			
			cube.box.x = isNaN(x) ? -15. + Math.random() * 30. : x;
			cube.box.y = isNaN(y) ? 50. : y;
			cube.box.z = isNaN(z) ? -15. + Math.random() * 30. : z;
			
			_physics.system.addBody(cube.rigidBody);
			
			pg.useHandCursor = true;
			pg.addEventListener(MouseEvent.CLICK, function(e : Event) : void
			{
				shoot(cube);
			});
			
			_cubes.addChild(pg);
			
			return cube;
		}
		
		private function mouseMoveHandler(event : MouseEvent) : void
		{
			if (event.buttonDown)
			{
				_camera.rotation.y -= (event.stageX - _cursor.x) * MOUSE_SENSITIVITY;
				_camera.rotation.x -= (event.stageY - _cursor.y) * MOUSE_SENSITIVITY;
			}		
			
			_cursor.x = event.stageX;
			_cursor.y = event.stageY;
		}
		
		private function keyDownHandler(event : KeyboardEvent) : void
		{
			switch (event.keyCode)
			{
				case Keyboard.PAGE_UP :
					_light.diffuse = Math.min(_light.diffuse + .1, .5);
					break ;
				case Keyboard.PAGE_DOWN :
					_light.diffuse = Math.max(_light.diffuse - .1, 0.);
					break ;
				case Keyboard.UP :
					_speed.x = WALK_SPEED;
					break ;
				case Keyboard.DOWN :
					_speed.x = -WALK_SPEED;
					break ;
				case Keyboard.LEFT :
					_speed.y = -WALK_SPEED;
					break ;
				case Keyboard.RIGHT :
					_speed.y = WALK_SPEED;
					break ;
				case Keyboard.ENTER :
					shoot();
					break ;
				case Keyboard.SPACE :
					createCube();
					break ;
				case Keyboard.F2 :
					Monitor.monitor.visible = !Monitor.monitor.visible;
					break ;
				case Keyboard.F :
					if (stage.displayState == StageDisplayState.NORMAL)
						stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
					else
						stage.displayState = StageDisplayState.NORMAL;
					break ;
			}
		}
	
		private function shoot(box : BoxSkinGroup = null) : void
		{
			var minDistance 	: Number 		= box ? 0. : int.MAX_VALUE;
			var shootDirection 	: Vector4 		= null;
			
			if (!box)
			{
				for each (var pg : PickableGroup in _cubes)
				{
					var cube : BoxSkinGroup = pg[0];
					var direction : Vector4 = Vector4.subtract(new Vector4(cube.box.x, cube.box.y, cube.box.z),
															   _camera.position);
					
					if (direction.length < minDistance)
					{
						shootDirection = direction;
						minDistance = direction.length;
						box = cube;
					}
				}
			}
			else
			{
				shootDirection = Vector4.subtract(new Vector4(box.rigidBody.x, box.rigidBody.y, box.rigidBody.z),
												  _camera.position);
			}
			
			if (minDistance < 20.)
			{
				shootDirection.normalize()
							  .scaleBy(100.);
				shootDirection.y *= 2.;
				box.rigidBody.applyBodyWorldImpulse(shootDirection.toVector3D(), Vector3D.Y_AXIS);
			}
		}
		
		private function keyUpHandler(event : KeyboardEvent) : void
		{
			switch (event.keyCode)
			{
				case Keyboard.UP :
				case Keyboard.DOWN :
					_speed.x = 0.;
					break ;
				case Keyboard.LEFT :
				case Keyboard.RIGHT :
					_speed.y = 0.;
					break ;
			}
		}
		
		private function enterFrameHandler(event : Event) : void
		{
			var collisions : Boolean = false;
			
			for (var i : int = 0; i < _cubes.numChildren; ++i)
				_cubes[i]..light.diffuse = .5 + Math.sin(i + getTimer() * .001) * .5;
			
			_physics.update();
			
			_camera.walk(_speed.x);
			_camera.strafe(_speed.y);
			if (_camera.position.x > 45.)
				_camera.position.x = 45.;
			else if (_camera.position.x < -45.)
				_camera.position.x = -45.;
			if (_camera.position.z > 45.)
				_camera.position.z = 45.;
			else if (_camera.position.z < -45.)
				_camera.position.z = -45.;
			
			_viewport.render(_scene);
		}
		
	}
}
