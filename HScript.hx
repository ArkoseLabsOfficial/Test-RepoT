package funkin.backend.scripting;

class Script extends FlxBasic implements IFlxDestroyable {
	/**
	 * Use "static var thing = true;" in hscript to use those!!
	 * are reset every menu switch so once you're done with them make sure to make them null!!
	 */
	public static var staticVariables:Map<String, Dynamic> = [];

	public static function getDefaultVariables(?script:Script):Map<String, Dynamic> {
		return [
			/* Psych Extended related stuff */
			"Mods"		  => backend.Mods,
			"AttachedSprite"		  => objects.AttachedSprite,
			"ClientPrefs"		  => backend.ClientPrefs,
			"FunkinFileSystem"		  => backend.FunkinFileSystem,
			"Converters"		  => backend.Converters,

			/* Sys related stuff */
			"File"		  => File,
			"Process"		  => sys.io.Process,
			"FileSystem"		  => FileSystem,
			"Thread"		  => CoolUtil.getMacroAbstractClass("sys.thread.Thread"),
			"Mutex"		  => CoolUtil.getMacroAbstractClass("sys.thread.Mutex"),

			/* Haxe related stuff */
			"Std"			   => Std,
			"Math"			  => Math,
			"Type"			  => Type,
			"Date"			  => Date,
			"Array"			  => Array,
			"Reflect"			  => Reflect,
			"StringTools"	   => StringTools,
			"Json"			  => haxe.Json,
			"Access"			  => CoolUtil.getMacroAbstractClass("haxe.xml.Access"),

			/* OpenFL & Lime related stuff */
			"Assets"			=> openfl.utils.Assets,
			"TextField"		  => openfl.text.TextField,
			"Application"	   => lime.app.Application,
			"Main"				=> Main,
			"window"			=> lime.app.Application.current.window,

			/* Flixel related stuff */
			"FlxG"			  => flixel.FlxG,
			"FlxSprite"		 => flixel.FlxSprite,
			"FlxBasic"		  => flixel.FlxBasic,
			"FlxCamera"		 => flixel.FlxCamera,
			"state"			 => flixel.FlxG.state,
			"FlxEase"		   => flixel.tweens.FlxEase,
			"FlxTween"		  => flixel.tweens.FlxTween,
			"FlxSound"		  => flixel.sound.FlxSound,
			"FlxAssets"		 => flixel.system.FlxAssets,
			"FlxMath"		   => flixel.math.FlxMath,
			"FlxGroup"		  => flixel.group.FlxGroup,
			"FlxTypedGroup"	 => flixel.group.FlxGroup.FlxTypedGroup,
			"FlxSpriteGroup"	=> flixel.group.FlxSpriteGroup,
			"FlxTypeText"	   => flixel.addons.text.FlxTypeText,
			"FlxText"		   => flixel.text.FlxText,
			"FlxTimer"		  => flixel.util.FlxTimer,
			"FlxFlicker"		  => flixel.effects.FlxFlicker,
			"FlxBackdrop"		  => flixel.addons.display.FlxBackdrop,
			"FlxOgmo3Loader"		  => flixel.addons.editors.ogmo.FlxOgmo3Loader,
			"FlxTilemap"		  => flixel.tile.FlxTilemap,
			"FlxTextBorderStyle"		  => flixel.text.FlxTextBorderStyle,
			"FlxTextAlign"	  => CoolUtil.getMacroAbstractClass("flixel.text.FlxText.FlxTextAlign"),
			"FlxPoint"		  => CoolUtil.getMacroAbstractClass("flixel.math.FlxPoint"),
			"FlxAxes"		   => CoolUtil.getMacroAbstractClass("flixel.util.FlxAxes"),
			"FlxColor"		  => CoolUtil.getMacroAbstractClass("flixel.util.FlxColor"),
			"BlendMode"		  => CoolUtil.getMacroAbstractClass("openfl.display.BlendMode"),

			/* Objects */
			"FlxAnimate"		=> flxanimate.FlxAnimate, //PsychFlxAnimate is removed for CNE compatibility
			"HealthIcon"		=> objects.HealthIcon,
			"Note"				=> objects.Note,
			"Character"		=> objects.Character,
			"Boyfriend"			=> objects.Character, // for compatibility

			/* Backend */
			"Alphabet"			=> objects.Alphabet,
			"Paths"			=> backend.Paths,
			"Conductor"		=> backend.Conductor,
			"CoolUtil"			=> backend.CoolUtil,

			/* Codename Engine related stuff */
			"FunkinShader"	=> funkin.backend.shaders.FunkinShader,
			"CustomShader"	=> funkin.backend.shaders.CustomShader,
			"FunkinText"		=> funkin.backend.FunkinText,
			"FunkinSprite"		=> funkin.backend.FunkinSprite,

			/* States */
			"PlayState"		 => states.PlayState,
			"FreeplayState"	 => states.FreeplayState,
			"MainMenuState"	 => states.MainMenuState,
			"PauseSubState"	 => substates.PauseSubState,
			"StoryMenuState"	 => states.StoryMenuState,
			"TitleState"		 => states.TitleState,
			"OptionsState"		 => options.OptionsState,
			"LoadingState"		 => states.LoadingState,
			"MusicBeatState"	 => backend.MusicBeatState,

			/* Substates */
			"GameOverSubstate"  => substates.GameOverSubstate,
			"MusicBeatSubstate"  => backend.MusicBeatSubstate,
			"PauseSubstate"	 => substates.PauseSubState,

			/* Custom Menus */
			#if SCRIPTING_ALLOWED
			"ModState"		  => funkin.backend.scripting.ModState,
			"ModSubState"		  => funkin.backend.scripting.ModSubState,
			#end

			/* hxVLC */
			"FlxVideo"		  => hxvlc.flixel.FlxVideo,
			"FlxVideoSprite"		  => hxvlc.flixel.FlxVideoSprite,

			/* hxCodec 2.6.0 things */
			/*
			"VideoHandler"		  => VideoHandler,
			"VideoSprite"		  => VideoSprite,
			*/

			/* hxCodec 2.5.1 */
			"MP4Handler"		  => vlc.MP4Handler,
			//"MP4Sprite"		  => vlc.MP4Sprite,
			
			//Online Stuffs
			"GameClient"	=> online.GameClient,
		];
	}

	public static function getDefaultPreprocessors():Map<String, Dynamic> {
		var defines = macros.DefineMacro.defines;
		return defines;
	}

	/**
	 * All available script extensions
	 */
	public static var scriptExtensions:Array<String> = [
		"hx", "hscript", "hsc", "hxs",
		"pack", // combined file
		"lua" /** ACTUALLY NOT SUPPORTED, ONLY FOR THE MESSAGE **/
	];

	/**
	 * Currently executing script.
	 */
	public static var curScript:Script = null;

	/**
	 * Script name (with extension)
	 */
	public var fileName:String;

	/**
	 * Script Extension
	 */
	public var extension:String;

	/**
	 * Path to the script.
	 */
	public var path:String;

	private var rawPath:String = null;

	private var didLoad:Bool = false;

	public var remappedNames:Map<String, String> = [];

	/**
	 * Creates a script from the specified asset path. The language is automatically determined.
	 * @param path Path in assets
	 */
	public static function create(path:String):Script {
		if (FunkinFileSystem.exists(path)) {
			return switch(Path.extension(path).toLowerCase()) {
				case "hx" | "hscript" | "hsc" | "hxs":
					new HScript(path);
				case "pack":
					var arr = FunkinFileSystem.getText(path).split("________PACKSEP________");
					fromString(arr[1], arr[0]);
				case "lua":
					trace("Lua is not supported in custom menus. Use HScript instead.");
					new DummyScript(path);
				default:
					new DummyScript(path);
			}
		}
		return new DummyScript(path);
	}

	/**
	 * Creates a script from the string. The language is determined based on the path.
	 * @param code code
	 * @param path filename
	 */
	public static function fromString(code:String, path:String):Script {
		return switch(Path.extension(path).toLowerCase()) {
			case "hx" | "hscript" | "hsc" | "hxs":
				new HScript(path).loadFromString(code);
			case "lua":
				trace("Lua is not supported in this engine. Use HScript instead.");
				new DummyScript(path).loadFromString(code);
			default:
				new DummyScript(path).loadFromString(code);
		}
	}

	/**
	 * Creates a new instance of the script class.
	 * @param path
	 */
	public function new(path:String) {
		super();

		rawPath = path;
		//path = path;

		this.fileName = Path.withoutDirectory(path);
		this.extension = Path.extension(path);
		this.path = path;
		onCreate(path);
		for(k=>e in getDefaultVariables(this)) {
			set(k, e);
		}
		set("disableScript", () -> {
			active = false;
		});
		set("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name'))
			{
				var save:FlxSave = new FlxSave();
				// folder goes unused for flixel 5 users. @BeastlyGhost
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			trace('initSaveData: Save file already initialized: ' + name);
		});
		set("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			trace('getDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
			return defaultValue;
		});
		set("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			trace('setDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
		});
		set("__script__", this);

		//trace('Loading script at path \'${path}\'');
	}

	/**
	 * Loads the script
	 */
	public function load() {
		//if(didLoad) return; //this shit brokes the update functions (maybe I can fix this later)

		var oldScript = curScript;
		curScript = this;
		onLoad();
		curScript = oldScript;

		didLoad = true;
	}

	/**
	 * HSCRIPT ONLY FOR NOW
	 * Sets the "public" variables map for ScriptPack
	 */
	public function setPublicMap(map:Map<String, Dynamic>) {

	}

	/**
	 * Hot-reloads the script, if possible
	 */
	public function reload() {

	}

	/**
	 * Traces something as this script.
	 */
	public function trace(v:Dynamic) {
		var fileName = this.fileName;
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		trace('${fileName}: ' + Std.string(v));
	}

	/**
	 * Calls the function `func` defined in the script.
	 * @param func Name of the function
	 * @param parameters (Optional) Parameters of the function.
	 * @return Result (if void, then null)
	 */
	public function call(func:String, ?parameters:Array<Dynamic>):Dynamic {
		var oldScript = curScript;
		curScript = this;

		var result = onCall(func, parameters == null ? [] : parameters);

		curScript = oldScript;
		return result;
	}

	/**
	 * Loads the code from a string, doesnt really work after the script has been loaded
	 * @param code The code.
	 */
	public function loadFromString(code:String) {
		return this;
	}

	/**
	 * Sets a script's parent object so that its properties can be accessed easily. Ex: Passing `PlayState.instance` will allow `boyfriend` to be typed instead of `PlayState.instance.boyfriend`.
	 * @param variable Parent variable.
	 */
	public function setParent(variable:Dynamic) {}

	/**
	 * Gets the variable `variable` from the script's variables.
	 * @param variable Name of the variable.
	 * @return Variable (or null if it doesn't exists)
	 */
	public function get(variable:String):Dynamic {return null;}

	/**
	 * Sets the variable `variable` from the script's variables.
	 * @param variable Name of the variable.
	 * @return Variable (or null if it doesn't exists)
	 */
	public function set(variable:String, value:Dynamic):Void {}

	public function setupPlayState():Void {}

	/**
	 * Shows an error from this script.
	 * @param text Text of the error (ex: Null Object Reference).
	 * @param additionalInfo Additional information you could provide.
	 */
	public function error(text:String, ?additionalInfo:Dynamic):Void {
		var fileName = this.fileName;
		if(remappedNames.exists(fileName))
			fileName = remappedNames.get(fileName);
		trace(fileName + text);
	}

	override public function toString():String {
		return FlxStringUtil.getDebugString(didLoad ? [
			LabelValuePair.weak("path", path),
			LabelValuePair.weak("active", active),
		] : [
			LabelValuePair.weak("path", path),
			LabelValuePair.weak("active", active),
			LabelValuePair.weak("loaded", didLoad),
		]);
	}

	/**
	 * PRIVATE HANDLERS - DO NOT TOUCH
	 */
	private function onCall(func:String, parameters:Array<Dynamic>):Dynamic {
		return null;
	}
	public function onCreate(path:String) {}

	public function onLoad() {}
}
