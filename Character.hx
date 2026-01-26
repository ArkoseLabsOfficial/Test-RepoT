package objects;

// --- PSYCH IMPORTS ---
import online.away.AnimatedSprite3D;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import openfl.utils.AssetType;
import openfl.utils.Assets;
import tjson.TJSON as Json;
import backend.Song;
import backend.Section;
import states.stages.objects.TankmenBG;
import online.GameClient;
import flixel.addons.effects.FlxSkewedSprite;
import funkin.backend.utils.XMLUtil; // Assuming you have this from CNE
import haxe.xml.Access;
import haxe.Exception;

// --- CNE / SCRIPTING IMPORTS ---
import funkin.backend.scripting.DummyScript;
import funkin.backend.scripting.Script;
import funkin.backend.scripting.ScriptPack;
import funkin.backend.scripting.events.CancellableEvent;
import funkin.backend.scripting.events.character.*;
import funkin.backend.scripting.events.sprite.*;
import funkin.backend.scripting.events.PointEvent;
import funkin.backend.scripting.events.DrawEvent;
import funkin.backend.system.interfaces.IBeatReceiver; // Assuming you have this interface

using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	@:optional var vocals_file:String;
	@:optional var dead_character:Null<String>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var sound:String;
	@:optional var flip_x:Bool;
}

class Character extends FlxSkewedSprite implements IBeatReceiver {
	public var sprite3D:AnimatedSprite3D;

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;
	public var isMissing:Bool = false;
	public var colorTween:FlxTween;
	
	// Networking
	public var noteHold(default, set):Bool = false;
	function set_noteHold(v) {
		if (PlayState.isCharacterPlayer(this) && noteHold != v) {
			GameClient.send("noteHold", v);
		}
		return noteHold = v;
	}

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4;
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;
	public var vocalsFile:String = '';
	public var deadName:String = null;

	public var gameIconIndex:Int = 0;
	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	var ogPositionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var ox:Int = 0;
	public var hasMissAnimations:Bool = true;

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];
	public var isSkin:Bool = false;
	public var loadFailed:Bool = false;

	public var animSounds:Map<String, openfl.media.Sound> = new Map<String, openfl.media.Sound>();
	public var sound:FlxSound;

	public var modDir:String = null;
	public var animSuffix:String;

	// --- CNE SYSTEMS ---
	public var xml:Access;
	public var scripts:ScriptPack;
	public var script(default, set):Script;
	public var playerOffsets:Bool = false; // CNE: Defines if offsets are designed for player-side
	public var globalOffset:FlxPoint = new FlxPoint(0, 0); // CNE: Global offset point
	
	// Compatibility Helpers for scripts
	public var Custom(get, set):Bool;
	function set_Custom(value:Bool):Bool { return this.isSkin = value; }
	function get_Custom():Bool { return this.isSkin; }
	public var custom(get,never):Bool;
	function get_custom():Bool { return this.isSkin; }

	public static var DEFAULT_CHARACTER:String = 'bf'; 

	// Helper to find XML files (CNE Style)
	public static function getXMLFromCharName(character:String):Access {
		var xml:Access = null;
		var characterPath:String = 'characters/' + character + '.xml';
		
		#if MODS_ALLOWED
		var xmlPath:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(xmlPath)) {
			xmlPath = Paths.getPreloadPath(characterPath);
		}
		
		if (FileSystem.exists(xmlPath)) {
			try {
				var plainXML:String = File.getContent(xmlPath);
				var charXML:Xml = Xml.parse(plainXML).firstElement();
				if (charXML == null) throw new Exception("Missing \"character\" node in XML.");
				xml = new Access(charXML);
			} catch (e) {
				trace('Error while loading character XML ${character}: ${e}');
				return null;
			}
		}
		#else
		var xmlPath:String = Paths.getPreloadPath(characterPath);
		if (Assets.exists(xmlPath)) {
			try {
				var plainXML:String = Assets.getText(xmlPath);
				var charXML:Xml = Xml.parse(plainXML).firstElement();
				if (charXML == null) throw new Exception("Missing \"character\" node in XML.");
				xml = new Access(charXML);
			} catch (e) {
				trace('Error while loading character XML ${character}: ${e}');
				return null;
			}
		}
		#end
		
		return xml;
	}

	public static function getCharacterFile(character:String, ?instance:Character):CharacterFile {
		var characterPath:String = 'characters/' + character + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) path = Paths.getPreloadPath(characterPath);
		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Assets.exists(path))
		#end
		{
			if (instance != null) instance.loadFailed = true;
			path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER + '.json');
		}

		var rawJson = #if MODS_ALLOWED File.getContent(path) #else Assets.getText(path) #end;
		if (rawJson == null) return null;
		return cast Json.parse(rawJson);
	}

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, ?isSkin:Bool = false, ?charType:String) {
		super(x, y);

		modDir = Mods.currentModDirectory;
		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;
		this.isSkin = isSkin;

		// --- INIT SCRIPTS ---
		scripts = new ScriptPack([]);

		// 1. CHECK FOR XML (CNE SYSTEM)
		xml = getXMLFromCharName(curCharacter);

		if (xml != null) {
			// --- CNE XML PATH ---
			
			// Load associated script
			var scriptPathName = 'characters/$curCharacter';
			var scriptPath = Paths.script(scriptPathName); // Assuming you have Paths.script from CNE
			// Fallback if Paths.script isn't available:
			// var scriptPath = Paths.modFolders(scriptPathName + '.hx'); 

			script = Script.create(scriptPath);
			if (script == null) script = new DummyScript(curCharacter);
			
			scripts.add(script);
			script.load();
			
			// Trigger create
			scripts.call("create");

			// Build Character from XML
			buildCharacter(xml);
			
			// Note: buildCharacter handles positionArray, but we need to ensure flipX logic
			originalFlipX = flipX;

			// Post Create
			scripts.call("postCreate");

		} else {
			// --- PSYCH JSON PATH ---
			
			var library:String = null;
			switch (curCharacter) {
				// Hardcoded cases if any...
				default:
					var json:CharacterFile = getCharacterFile(curCharacter, this);
					isAnimateAtlas = false;

					var split:Array<String> = json.image.split(',');
					imageFile = split[0].trim();

					#if MODS_ALLOWED
					var modAnimToFind:String = Paths.modFolders('images/' + imageFile + '/Animation.json');
					var animToFind:String = Paths.getPath('images/' + imageFile + '/Animation.json', TEXT);
					if (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind))
					#else
					if (Assets.exists(Paths.getPath('images/' + imageFile + '/Animation.json', TEXT)))
					#end
					isAnimateAtlas = true;

					if (!isAnimateAtlas) {
						frames = Paths.getAtlas(imageFile);
					}
					#if flxanimate
					else {
						atlas = new FlxAnimate();
						atlas.showPivot = false;
						try { Paths.loadAnimateAtlas(atlas, imageFile); }
						catch(e:Dynamic) { FlxG.log.warn('Could not load atlas ${imageFile}: $e'); }
					}
					#end

					if (frames != null) {
						if (!loadFailed && graphic.bitmap != null && FlxG.state is PlayState && PlayState.instance.stage3D != null) {
							sprite3D = PlayState.instance.stage3D.createSprite(charType, true, graphic.bitmap);
						}
						// Multiatlas support
						for (i in 1...split.length) {
							var imgFile = split[i].trim();
							var daAtlas = Paths.getAtlas(imgFile);
							if (daAtlas != null) cast(frames, FlxAtlasFrames).addAtlas(daAtlas);
						}
					}

					if (json.scale != 1) {
						jsonScale = json.scale;
						scale.set(jsonScale, jsonScale);
						updateHitbox();
					}

					ogPositionArray = positionArray = json.position;
					cameraPosition = json.camera_position;

					healthIcon = json.healthicon;
					singDuration = json.sing_duration;
					flipX = (json.flip_x == true);

					if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
						healthColorArray = json.healthbar_colors;

					vocalsFile = json.vocals_file ?? curCharacter;
					deadName = json.dead_character;

					noAntialiasing = (json.no_antialiasing == true);
					antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

					animationsArray = json.animations;
					if (animationsArray != null && animationsArray.length > 0) {
						for (anim in animationsArray) {
							var animAnim:String = '' + anim.anim;
							var animName:String = '' + anim.name;
							var animFps:Int = anim.fps;
							var animLoop:Bool = !!anim.loop;
							var animIndices:Array<Int> = anim.indices;
							var flipX:Bool = !!anim.flip_x;
							
							if(!isAnimateAtlas) {
								if (animIndices != null && animIndices.length > 0)
									animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop, flipX);
								else
									animation.addByPrefix(animAnim, animName, animFps, animLoop, flipX);
							}
							#if flxanimate
							else {
								if(animIndices != null && animIndices.length > 0)
									atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
								else
									atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
							}
							#end

							if (anim.offsets != null && anim.offsets.length > 1) 
								addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
							else
								addOffset(anim.anim, 0, 0);

							if (anim.sound != null) {
								var sound = Paths.sound(anim.sound);
								if (sound != null) animSounds.set(animAnim, sound);
							}
						}
					} else {
						quickAnimAdd('idle', 'BF idle dance');
					}
					
					setup3D();
					#if flxanimate
					if(isAnimateAtlas) copyAtlasValues();
					#end
					
					originalFlipX = flipX;
			}
		}

		// --- COMMON FINALIZATION ---

		if(animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss')) hasMissAnimations = true;
		
		recalculateDanceIdle();
		dance();

		if (isPlayer) {
			flipX = !flipX;
			
			// Psych Engine standard flip logic for miss animations not needed for CNE chars generally,
			// but we keep it for consistency with Psych JSONs.
			/*
			if (!curCharacter.startsWith('bf')) {
				// Old Psych flipping logic...
			}
			*/
		}

		if (curCharacter.endsWith('-speaker') && loadMappedAnims()) {
			playAnim("shoot1");
		}
	}

	// --- CNE BUILD LOGIC ---
	public function buildCharacter(xml:Access) {
		// Properties
		if (xml.has.x) positionArray[0] = Std.parseFloat(xml.att.x);
		if (xml.has.y) positionArray[1] = Std.parseFloat(xml.att.y);
		if (xml.has.camx) cameraPosition[0] = Std.parseFloat(xml.att.camx);
		if (xml.has.camy) cameraPosition[1] = Std.parseFloat(xml.att.camy);
		if (xml.has.holdTime) singDuration = Std.parseFloat(xml.att.holdTime);
		if (xml.has.flipX) flipX = (xml.att.flipX == "true");
		if (xml.has.icon) healthIcon = xml.att.icon;
		if (xml.has.scale) {
			jsonScale = Std.parseFloat(xml.att.scale);
			scale.set(jsonScale, jsonScale);
		}
		if (xml.has.antialiasing) antialiasing = (xml.att.antialiasing == "true");
		if (xml.has.sprite) imageFile = xml.att.sprite;
		
		// CNE Specific: playerOffsets
		// If true, offsets are designed for BF position. If false (default), designed for Dad position.
		if (xml.has.playerOffsets) playerOffsets = (xml.att.playerOffsets == "true");

		// Colors
		if (xml.has.color) {
			var colorStr = xml.att.color;
			if(colorStr.startsWith("#")) colorStr = colorStr.substring(1);
			healthColorArray = FlxColor.fromString("#" + colorStr).getRGB();
		}

		// Atlas
		frames = Paths.getAtlas(imageFile);

		// Animations
		for (anim in xml.nodes.anim) {
			var name = anim.att.name; // Internal name (idle, singUP)
			var animName = anim.att.anim; // XML prefix
			var fps = anim.has.fps ? Std.parseInt(anim.att.fps) : 24;
			var loop = anim.has.loop ? (anim.att.loop == "true") : false;
			var x = anim.has.x ? Std.parseFloat(anim.att.x) : 0.0;
			var y = anim.has.y ? Std.parseFloat(anim.att.y) : 0.0;
			var flip = anim.has.flipX ? (anim.att.flipX == "true") : false;

			if (anim.has.indices) {
				var indices:Array<Int> = [];
				var strIndices = anim.att.indices.split(",");
				for (i in strIndices) indices.push(Std.parseInt(i));
				animation.addByIndices(name, animName, indices, "", fps, loop, flip);
			} else {
				animation.addByPrefix(name, animName, fps, loop, flip);
			}

			addOffset(name, x, y);
		}
	}

	public function setup3D() {
		if (sprite3D != null) {
			sprite3D.addAnimationsFromFlxSprite(this);
			for (name => offset in animOffsets) {
				sprite3D.animations.get(name).setOffset(offset[0], offset[1]);
			}
			sprite3D.scaleX = jsonScale;
			sprite3D.scaleY = jsonScale;
			sprite3D.antialiasing = !noAntialiasing;
			visible = false;
		}
	}

	public var noAnimationBullshit:Bool = false;

	override function update(elapsed:Float) {
		// Script Hook
		if (scripts != null) scripts.call("update", [elapsed]);

		if(isAnimateAtlas) atlas.update(elapsed);

		if (sprite3D != null) {
			sprite3D.play(animation.name, animation.curAnim.curFrame, true);
		}

		if (noAnimationBullshit) {
			super.update(elapsed);
			return;
		}

		if (!debugMode && !isAnimationNull()) {
			if (heyTimer > 0) {
				heyTimer -= elapsed * (PlayState.instance?.playbackRate ?? 1);
				if (heyTimer <= 0) {
					var anim:String = getAnimationName();
					if (specialAnim && anim == 'hey' || anim == 'cheer') {
						specialAnim = false;
						dance();
					}
				}
			} else if (specialAnim && isAnimationFinished()) {
				specialAnim = false;
				dance();
			}
			
			if (!isPlayer) {
				if (animation.name.startsWith('sing')) {
					holdTimer += elapsed;
				}

				if (holdTimer >= Conductor.stepCrochet * (0.0011 / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1)) * singDuration) {
					dance();
					holdTimer = 0;
				}
			}

			if (isAnimationFinished() && animation.getByName(animation.name + '-loop') != null) {
				playAnim(animation.name + '-loop');
			}
		}

		super.update(elapsed);
		if(colorTween != null) color = colorTween.value;

		// Script Hook
		if (scripts != null) scripts.call("postUpdate", [elapsed]);
	}

	public var danced:Bool = false;

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0){
		// Script Hook (Event based)
		if (scripts != null) {
			var event = new PlayAnimEvent(AnimName, Force, Reversed, Frame);
			scripts.call("onPlayAnim", [event]);
			if (event.cancelled) return;
			AnimName = event.animName;
			Force = event.force;
			Reversed = event.reverse;
			Frame = event.startingFrame;
		}

		specialAnim = false;
		if (animation.getByName(AnimName) == null) return;

		#if flxanimate
		if(isAnimateAtlas) atlas.anim.play(AnimName, Force, Reversed, Frame);
		else
		#end
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		
		// --- CNE OFFSET LOGIC ---
		var offsetX:Float = 0;
		var offsetY:Float = 0;

		if (animOffsets.exists(AnimName)) {
			offsetX = daOffset[0];
			offsetY = daOffset[1];
		}

		// Apply Global Offsets
		// Note: In CNE, globalOffset is added.
		// Also handle the "isPlayer != playerOffsets" logic
		// If character is flipped (isPlayer != playerOffsets), we often need to adjust the X offset.
		if (isPlayer != playerOffsets) {
			// CNE formula for flipped offsets:
			// offset.x = (frameWidth * scale.x) - offset.x - (width * scale.x) ... roughly
			// But since Psych handles flipping via `flipX`, simple offset mapping often works differently.
			// Standard CNE implementation:
			// offset.set(globalOffset.x * (isPlayer != playerOffsets ? 1 : -1), -globalOffset.y);
			
			// We will stick to applying the raw offset, but keep globalOffset in mind.
			// If you really want CNE's "flip logic", you might need:
			// offsetX = (frameWidth) - offsetX - width; 
			// But Psych usually relies on the `flipX` property of the sprite doing the work.
		}

		// Apply the calculated offsets
		var offsetType = #if flxanimate isAnimateAtlas ? atlas.offset : #end offset;
		offsetType.set(offsetX + globalOffset.x, offsetY + globalOffset.y);
		// ------------------------

		if (curCharacter.startsWith('gf') || danceIdle) {
			if (AnimName == 'singLEFT') danced = true;
			else if (AnimName == 'singRIGHT') danced = false;
			if (AnimName == 'singUP' || AnimName == 'singDOWN') danced = !danced;
		}
	}

	public function dance() {
		if (!debugMode && !skipDance && !specialAnim) {
			if (scripts != null) {
				var event = new CancellableEvent();
				scripts.call("onDance", [event]);
				if (event.cancelled) return;
			}

			if (danceIdle) {
				danced = !danced;
				if (danced) playAnim('danceRight' + idleSuffix);
				else playAnim('danceLeft' + idleSuffix);
			}
			else if (animation.getByName('idle' + idleSuffix) != null) {
				playAnim('idle' + idleSuffix);
			}
		}
	}

	// Interface implementation for IBeatReceiver
	public function beatHit(curBeat:Int) {
		if (scripts != null) scripts.call("beatHit", [curBeat]);
	}
	
	public function stepHit(curStep:Int) {
		if (scripts != null) scripts.call("stepHit", [curStep]);
	}

	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if(settingCharacterUp) {
			danceOnBeat = (danceIdle || animation.getByName('idle' + idleSuffix) != null);
		}
		else if(lastDanceIdle != danceIdle) {
			var calc:Float = danceIdle ? 1/2 : 1;
			singDuration /= calc;
			holdTimer /= calc;
		
			if(singDuration < 1) singDuration = 1;
			if(holdTimer < 1) holdTimer = 1;

			if(danceIdle) {
				singDuration = Math.round(singDuration);
				holdTimer = Math.round(holdTimer);
			}
			else {
				singDuration = Math.round(Math.max(singDuration, 1));
				holdTimer = Math.round(Math.max(holdTimer, 1));
			}
		}
		settingCharacterUp = false;
	}

	public var danceOnBeat:Bool = false;
	private var settingCharacterUp:Bool = true;

	public function addOffset(name:String, x:Float = 0, y:Float = 0) {
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		if(!isAnimateAtlas)
			animation.addByPrefix(name, anim, 24, false);
		#if flxanimate
		else
			atlas.anim.addBySymbol(name, anim, 24, false);
		#end
	}

	public var isAnimateAtlas:Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;

	public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}
	
	public override function draw()
	{
		if (scripts != null) scripts.call("draw");

		if(isAnimateAtlas)
		{
			copyAtlasValues();
			atlas.draw();
			if (scripts != null) scripts.call("postDraw");
			return;
		}
		super.draw();
		if (scripts != null) scripts.call("postDraw");
	}
	#end

	public function isAnimationNull():Bool
	{
		#if flxanimate
		if(isAnimateAtlas) return atlas.anim.curSymbol == null;
		#end
		return animation.curAnim == null;
	}

	public function getAnimationName():String
	{
		var name:String = '';
		@:privateAccess
		#if flxanimate
		if(isAnimateAtlas) name = atlas.anim.curSymbol.name;
		else 
		#end
		if(animation.curAnim != null) name = animation.curAnim.name;
		return name;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		#if flxanimate
		if(isAnimateAtlas) return atlas.anim.finished;
		#end
		return animation.curAnim.finished;
	}

	var mappedAnims:Map<String, Int> = new Map<String, Int>();
	private function loadMappedAnims():Bool
	{
		try {
			var file:String = 'characters/$curCharacter.txt';
			#if MODS_ALLOWED
			var path:String = Paths.modFolders(file);
			if (!FileSystem.exists(path)) path = Paths.getPreloadPath(file);
			if (!FileSystem.exists(path))
			#else
			var path:String = Paths.getPreloadPath(file);
			if (!Assets.exists(path))
			#end
			return false;

			var content:String = #if MODS_ALLOWED File.getContent(path) #else Assets.getText(path) #end;
			var data:Array<String> = content.split('\n');
			for(i in data) {
				var spl:Array<String> = i.trim().split(' ');
				if(spl.length > 1) mappedAnims.set(spl[0], Std.parseInt(spl[1]));
			}
		} catch(e:Dynamic) {
			trace('Error loading mapped anims: $e');
			return false;
		}
		return true;
	}
	
	override function destroy() {
		if(scripts != null) {
			scripts.call('destroy');
			scripts.destroy();
		}
		super.destroy();
	}
}
