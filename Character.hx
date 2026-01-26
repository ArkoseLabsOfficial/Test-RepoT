package;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import Section;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

// Well Cne imports
import sys.FileSystem;
import sys.io.File;
import flixel.util.FlxSpriteUtil;
import openfl.display.Graphics;
import flixel.util.typeLimit.OneOfTwo;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import funkin.backend.scripting.HScript;
import funkin.backend.FunkinSprite;
import funkin.backend.system.interfaces.IBeatReceiver;
import funkin.backend.system.interfaces.IOffsetCompatible;
import funkin.backend.scripting.events.character.*;
import funkin.backend.scripting.events.sprite.*;
import funkin.backend.scripting.events.PointEvent;
import funkin.backend.scripting.events.DrawEvent;
import funkin.backend.utils.MatrixUtil;
import funkin.backend.utils.XMLUtil;
import haxe.Exception;
import haxe.io.Path;
import haxe.xml.Access;
import openfl.geom.ColorTransform;
import flixel.tweens.FlxTween;

// Online/OG imports
import online.away.AnimatedSprite3D; // Ensure you have this or comment it out if not needed
import online.GameClient; // Ensure you have this or comment it out if not needed

using StringTools;
using CoolUtil;

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
	@:optional var _editor_isPlayer:Null<Bool>;
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

/*
 * September 28, 2025: FlxSkewedSprite changed with FunkinMergedSprite for future compability
 * September 29, 2025: Character.hx & Character_CNE.hx merged for easier to understanding
 * Updated with OG-Character.hx naming conventions
*/
class Character extends FunkinMergedSprite implements IBeatReceiver implements IOffsetCompatible implements IPrePostDraw
{
	/* Codename Engine */
	public var canUseStageCamOffset:Bool = true;
	//StageOffsets can be disabled for cne chars, default is true
	public var groupEnabled:Bool = true;
	//cne doesn't have groups for chars, so you can disable this, default is true
	public var sprite:String = Flags.DEFAULT_CHARACTER;
	public var lastHit:Float = Math.NEGATIVE_INFINITY;
	public var holdTime:Float = 4;

	public var playerOffsets:Bool = false;

	public var icon:String = null;
	public var iconColor:Null<FlxColor> = null;
	public var gameOverCharacter:String = Character.FALLBACK_DEAD_CHARACTER;

	public var cameraOffset:FlxPoint = FlxPoint.get(0, 0);
	public var globalOffset:FlxPoint = FlxPoint.get(0, 0);
	public var extraOffset:FlxPoint = FlxPoint.get(0, 0);

	public var xml:Access;
	public var scripts:ScriptPack;
	public var xmlImportedScripts:Array<XMLImportedScriptInfo> = [];
	public var script(default, set):Script;

	public function prepareInfos(node:Access)
		return XMLImportedScriptInfo.prepareInfos(node, scripts, (infos) -> xmlImportedScripts.push(infos));
	
	@:noCompletion var __stunnedTime:Float = 0;
	@:noCompletion var __lockAnimThisFrame:Bool = false;

	@:noCompletion var __switchAnims:Bool = true;
	
	/* PsychEngine / OG Fields */
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';
	
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	// OG: name changed from missingCharacter to isMissing
	public var isMissing:Bool = false; 
	
	public var noteHold(default, set):Bool = false;
	function set_noteHold(v) {
		// Basic implementation if GameClient isn't available, otherwise uncomment below
		// if (PlayState.isCharacterPlayer(this) && noteHold != v) {
		// 	GameClient.send("noteHold", v);
		// }
		return noteHold = v;
	}

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	
	// OG: simplified stunned definition (CNE uses the setter for __stunnedTime logic, keeping CNE behavior for compatibility)
	public var stunned(default, set):Bool = false;
	
	public var singDuration:Float = 4;
	//Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false;
	//Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';
	public var deadName:String = null; // From OG

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;
	
	// OG Extras
	public var sprite3D:AnimatedSprite3D;
	public var colorTween:FlxTween;
	public var isSkin:Bool = false;
	public var loadFailed:Bool = false;
	public var animSounds:Map<String, openfl.media.Sound> = new Map<String, openfl.media.Sound>();

	public static function getCharacterFile(character:String, ?instance:Character):CharacterFile {
		var characterPath:String = 'characters/' + character + '.json';
		var path:String = Paths.getPath(characterPath, TEXT, null, true);

		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json');
			// If a character couldn't be found, change him to BF just to prevent a crash
			if (instance != null) {
				instance.isMissing = true;
				instance.loadFailed = true;
			}
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end
		
		if (rawJson == null) return null;
		return cast Json.parse(rawJson);
	}

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, switchAnims:Bool = true, disableScripts:Bool = false)
	{
		super(x, y);

		var pathChar:String = Paths.getPath('data/characters/$character.xml', TEXT, null, true);
		#if MODS_ALLOWED
		if (FileSystem.exists(pathChar))
		#else
		if (Assets.exists(pathChar))
		#end
		{
			if (isPlayer) healthColorArray = [0, 255, 0];
			trace("Codename Char Used");
			isCodenameChar = true;
			animOffsets_CNE = new Map<String, FlxPoint>();
			curCharacter = character != null ? character : Flags.DEFAULT_CHARACTER;
			this.isPlayer = isPlayer;
			__switchAnims = switchAnims;

			antialiasing = true;

			xml = getXMLFromCharName(this);

			if(!disableScripts)
				script = Script.create(Paths.script('data/characters/$curCharacter', null, false, ["hscript", "hsc", "hxs"]));
			if (script == null)
				script = new DummyScript(curCharacter);

			script.load();

			scripts.call("create");
			buildCharacter(xml);
			scripts.call("postCreate");
		}
		else {
			trace("Psych Char Used");
			isCodenameChar = false;
			animOffsets = new Map<String, Array<Dynamic>>();
			curCharacter = character;
			this.isPlayer = isPlayer;
			changeCharacter(character);

			switch(curCharacter)
			{
				case 'pico-speaker':
					skipDance = true;
					loadMappedAnims();
					playAnim("shoot1");
				case 'pico-blazin', 'darnell-blazin':
					skipDance = true;
			}
		}
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		isMissing = false;

		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			default:
				var json:CharacterFile = getCharacterFile(curCharacter, this);
				if (json != null) {
					loadCharacterFile(json);
				} else {
					trace('Error loading character file of "$character"');
				}
				
				if (isMissing) {
					missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
					missingText.alignment = CENTER;
				}
		}

		if(hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss')) hasMissAnimations = true;
		recalculateDanceIdle();
		dance();
	}

	public function loadCharacterFile(json:Dynamic)
	{
		isAnimateAtlas = false;

		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT, null, true);
		if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1);
		updateHitbox();

		if(!isAnimateAtlas)
		{
			var split:Array<String> = json.image.split(',');
			var charFrames:FlxAtlasFrames = Paths.getAtlas(split[0].trim());
			if(split.length > 1)
			{
				var original:FlxAtlasFrames = charFrames;
				charFrames = new FlxAtlasFrames(charFrames.parent);
				charFrames.addAtlas(original, true);
				for (i in 1...split.length)
				{
					var extraFrames:FlxAtlasFrames = Paths.getAtlas(split[i].trim());
					if(extraFrames != null)
						charFrames.addAtlas(extraFrames, true);
				}
			}
			frames = charFrames;
		}
		#if flxanimate
		else
		{
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(atlas, json.image);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas ${json.image}: $e');
				trace(e.stack);
			}
		}
		#end
		
		// OG logic for sprite3D (if applicable)
		if (frames != null && !loadFailed && graphic != null && graphic.bitmap != null) {
			// Place for sprite3D initialization if Stage3D is available in CNE
		}

		imageFile = json.image;
		jsonScale = json.scale;
		if(json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		
		// OG Logic for vocals and dead character
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		deadName = json.dead_character;
		
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop;
				var animIndices:Array<Int> = anim.indices;
				var animFlipX:Bool = !!anim.flip_x;

				if(!isAnimateAtlas)
				{
					if(animIndices != null && animIndices.length > 0)
						// Passed animFlipX (OG Feature)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop, animFlipX);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop, animFlipX);
				}
				#if flxanimate
				else
				{
					if(animIndices != null && animIndices.length > 0)
						atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
				#end

				if(anim.offsets != null && anim.offsets.length > 1) addOffsetPsych(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffsetPsych(anim.anim, 0, 0);
			}
		}
		#if flxanimate
		if(isAnimateAtlas) copyAtlasValuesPsych();
		#end
	}

	override function update(elapsed:Float)
	{
		if (isCodenameChar) {
			super.update(elapsed);
			scripts.call("update", [elapsed]);
			if (stunned) {
				__stunnedTime += elapsed;
				if (__stunnedTime > Flags.STUNNED_TIME)
					stunned = false;
			}

			if (!__lockAnimThisFrame && lastAnimContext != DANCE)
				tryDance();

			__lockAnimThisFrame = false;
		}
		else
		{
			if(isAnimateAtlas) atlas.update(elapsed);
			if(debugMode || (!isAnimateAtlas && animation.curAnim == null) || (isAnimateAtlas && (atlas.anim.curInstance == null || atlas.anim.curSymbol == null)))
			{
				super.update(elapsed);
				return;
			}

			if(heyTimer > 0)
			{
				var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
				heyTimer -= elapsed * rate;
				if(heyTimer <= 0)
				{
					var anim:String = getAnimationName();
					if(specialAnim && (anim == 'hey' || anim == 'cheer'))
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if(specialAnim && isAnimationFinished())
			{
				specialAnim = false;
				dance();
			}
			else if (getAnimationName().endsWith('miss') && isAnimationFinished())
			{
				dance();
				finishAnimation();
			}

			switch(curCharacter)
			{
				case 'pico-speaker':
					if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
					{
						var noteData:Int = 1;
						if(animationNotes[0][1] > 2) noteData = 3;

						noteData += FlxG.random.int(0, 1);
						playAnim('shoot' + noteData, true);
						animationNotes.shift();
					}
				case 'pico-blazin', 'darnell-blazin':
					if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
					{
						var noteData:Int = 1;
						if(animationNotes[0][1] > 2) noteData = 3;

						noteData += FlxG.random.int(0, 1);
						playAnim('shoot' + noteData, true);
						animationNotes.shift();
					}
			}

			if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
			else if(isPlayer) holdTimer = 0;

			if ((!isPlayer) && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
			{
				dance();
				holdTimer = 0;
			}

			var name:String = getAnimationName();
			if(isAnimationFinished() && hasAnimation('$name-loop'))
				playAnim('$name-loop');

			super.update(elapsed);
		}
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
	}

	var _lastPlayedAnimation:String;
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.curFrame = atlas.anim.length - 1;
	}

	public function hasAnimation(anim:String):Bool
	{
		return isCodenameChar ? hasAnimation_CNE(anim) : animOffsets.exists(anim);
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : atlas.anim.isPlaying;
	}
	private function set_animPaused(value:Bool):Bool
	{
		if(isAnimationNull()) return value;
		if(!isAnimateAtlas) animation.curAnim.paused = value;
		else
		{
			if(value) atlas.anim.pause();
			else atlas.anim.resume();
		} 
		return value;
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (isCodenameChar) {
			playAnim_CNE(AnimName, Force, Reversed, Frame);
			return;
		}

		specialAnim = false;
		if(isAnimateAtlas) atlas.anim.play(AnimName, Force, Reversed, Frame);
		else animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf') || curCharacter == 'pico-speaker')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function dance()
	{
		if (isCodenameChar) {
			dance_CNE();
			return;
		}

		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if(hasAnimation('idle' + idleSuffix))
			{
				playAnim('idle' + idleSuffix);
			}
		}
	}
	
	public function recalculateDanceIdle() {
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));
	}

	public function addOffsetPsych(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	/*
	 * CODENAME ENGINE STUFF
	*/
	public var isCodenameChar:Bool = false;
	public var animOffsets_CNE:Map<String, FlxPoint>;

	public function playAnim_CNE(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void {
		//CNE playAnim implementation logic handled by FunkinMergedSprite usually, 
		//but we defer to super or custom logic if needed.
		//Assuming CNE logic uses super.playAnim or similar internally if this is an override.
		//For now, just calling internal or super logic:
		if (xml == null) return;
		
		super.playAnim(AnimName, Force, Reversed, Frame);
		_lastPlayedAnimation = AnimName;
		
		// Handle CNE offsets
		if (animOffsets_CNE.exists(AnimName)) {
			var off = animOffsets_CNE.get(AnimName);
			offset.set(off.x, off.y);
		}
	}

	public function dance_CNE() {
		if (xml == null) return;
		if (!debugMode && !skipDance && !specialAnim) {
			//CNE Dance logic
			var idleAnim = (xml.x.exists("idle") ? xml.x.get("idle") : "idle");
			if (danceIdle) {
				danced = !danced;
				if (danced) playAnim_CNE("danceRight" + idleSuffix);
				else playAnim_CNE("danceLeft" + idleSuffix);
			} else {
				playAnim_CNE(idleAnim + idleSuffix);
			}
		}
	}

	public function hasAnimation_CNE(id:String):Bool {
		if (xml == null) return false;
		for(anim in xml.nodes.anim) {
			if (anim.att.name == id) return true;
		}
		return false;
	}

	public function tryDance() {
		if (isCodenameChar) dance_CNE();
		else dance();
	}
	
	public static function getXMLFromCharName(char:String):Access {
		var xml:Access = null;
		while(true) {
			var xmlPath:String = Paths.xml('characters/$char');
			if (!FileSystem.exists(xmlPath)) {
				char = FALLBACK_CHARACTER;
				continue;
			}

			var plainXML:String = File.getContent(xmlPath);
			try {
				var charXML:Xml = Xml.parse(plainXML).firstElement();
				if (charXML == null) throw new Exception("Missing \"character\" node in XML.");
				xml = new Access(charXML);
			} catch (e) {
				CoolUtil.showPopUp('Error while loading character ${char}: ${e}', 'ERROR');
				char = FALLBACK_CHARACTER;
				continue;
			}
			break;
		}
		return xml;
	}

	public static final FALLBACK_CHARACTER:String = "bf";
	public static final FALLBACK_DEAD_CHARACTER:String = "bf-dead";

	public static function getIconFromCharName(?character:String, ?defaultIcon:String = null) {
		if(character == null) return Flags.DEFAULT_HEALTH_ICON;
		if(defaultIcon == null) defaultIcon = character;
		var icon:String = defaultIcon;

		var xml:Access = getXMLFromCharName(character);
		if (xml != null && xml.x.exists("icon")) icon = xml.x.get("icon");

		return icon;
	}
}

class CamPosData {
	public var pos:FlxPoint;
	public var amount:Int;
	public function new(pos:FlxPoint, amount:Int) {
		this.pos = pos;
		this.amount = amount;
	}
}
