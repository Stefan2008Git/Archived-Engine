package states;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import flixel.input.keyboard.FlxKey;
import backend.ClientPrefs;
import backend.CoolUtil;
#if desktop
import backend.Discord.DiscordClient;
#end
import backend.MusicBeatState;
import backend.Paths;
import backend.WeekData;
import shaders.ColorblindFilter;
import states.FreeplayState;
import states.editors.MasterEditorMenu;
import options.OptionsState;

using StringTools;

class MainMenuState extends MusicBeatState
{
	public static var sbEngineVersion:String = '2.9.0';
	public static var psychEngineVersion:String = '0.6.3';
	public static var currentlySelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	private var cameraGame:FlxCamera;
	
	var optionSelect:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits',
		'options'
	];

	var menuBackground:FlxSprite;
	var background:FlxSprite;
	var velocityBackground:FlxBackdrop;
	var versionSb:FlxText;
	var versionPsych:FlxText;
	var versionFnf:FlxText;
	var galleryText:FlxText;
	var galleryTextSine:Float = 0;
	var secretText:FlxText;
	var secretTextSine:Float = 0;
	var debugKeys:Array<FlxKey>;

	var tipTextMargin:Float = 10;
	var tipTextScrolling:Bool = false;
	var tipBackground:FlxSprite;
	var tipText:FlxText;
	var isTweening:Bool = false;
	var lastString:String = '';

	var cameraFollow:FlxObject;
	var cameraFollowPosition:FlxObject;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();
		if (ClientPrefs.colorblindMode != null)
			ColorblindFilter.applyFiltersOnGame();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Main Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		cameraGame = new FlxCamera();

		FlxG.cameras.reset(cameraGame);
		FlxG.cameras.setDefaultDrawTarget(cameraGame, true);

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionSelect.length - 4)), 0.1);
		menuBackground = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		menuBackground.scrollFactor.set(0, yScroll);
		menuBackground.setGraphicSize(Std.int(menuBackground.width * 1.175));
		menuBackground.updateHitbox();
		menuBackground.screenCenter();
		menuBackground.antialiasing = ClientPrefs.globalAntialiasing;
		add(menuBackground);

		velocityBackground = new FlxBackdrop(FlxGridOverlay.createGrid(30, 30, 60, 60, true, 0x3B161932, 0x0), XY);
		velocityBackground.velocity.set(FlxG.random.bool(50) ? 90 : -90, FlxG.random.bool(50) ? 90 : -90);
		velocityBackground.visible = ClientPrefs.velocityBackground;
		velocityBackground.alpha = 0;
		add(velocityBackground);

		cameraFollow = new FlxObject(0, 0, 1, 1);
		cameraFollowPosition = new FlxObject(0, 0, 1, 1);
		add(cameraFollow);
		add(cameraFollowPosition);

		background = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		background.scrollFactor.set(0, yScroll);
		background.setGraphicSize(Std.int(background.width * 1.175));
		background.updateHitbox();
		background.screenCenter();
		background.visible = false;
		background.antialiasing = ClientPrefs.globalAntialiasing;
		switch (ClientPrefs.themes) {
			case 'SB Engine':
				background.color = 0xFF800080;
			
			case 'Psych Engine':
				background.color = 0xFFea71fd;
		}
		// background.scrollFactor.set();
		add(background);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var scale:Float = 1;

		for (i in 0...optionSelect.length)
		{
			var offset:Float = 108 - (Math.max(optionSelect.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140)  + offset);
			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionSelect[i]);
			menuItem.animation.addByPrefix('idle', optionSelect[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionSelect[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (optionSelect.length - 4) * 0.135;
			if(optionSelect.length < 6) scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = ClientPrefs.globalAntialiasing;
			//menuItem.setGraphicSize(Std.int(menuItem.width * 0.58));
			menuItem.updateHitbox();
		}

		FlxG.camera.follow(cameraFollowPosition, null, 1);

		#if android
	    galleryText = new FlxText(12, FlxG.height - 44, FlxG.width - 24, "Press X for the gallery basemant!", 12);
		#else
		galleryText = new FlxText(12, FlxG.height - 44, FlxG.width - 24, "Press G for the gallery basemant!", 12);
		#end
		#if android
	    secretText = new FlxText(12, FlxG.height - 24, FlxG.width - 24, "Press Y for the secret screen!", 12);
		#else
		secretText = new FlxText(12, FlxG.height - 24, FlxG.width - 24, "Press S for the secret screen!", 12);
		#end
		versionSb = new FlxText(12, FlxG.height - 64, 0, "SB Engine v" + sbEngineVersion + " (Modified Psych Engine)", 16);
		versionPsych = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 16);
		versionFnf = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 16);
		switch (ClientPrefs.gameStyle) {
			case 'SB Engine': 
				galleryText.setFormat("Bahnschrift", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				secretText.setFormat("Bahnschrift", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionSb.setFormat("Bahnschrift", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionPsych.setFormat("Bahnschrift", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionFnf.setFormat("Bahnschrift", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

			case 'Psych Engine':
				galleryText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				secretText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionSb.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionPsych.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionFnf.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

			case 'Better UI':
				galleryText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				secretText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionSb.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionPsych.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

				versionFnf.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		}
		galleryText.scrollFactor.set();
		secretText.scrollFactor.set();
		versionSb.scrollFactor.set();
		versionPsych.scrollFactor.set();
		versionFnf.scrollFactor.set();
		add(galleryText);
		add(secretText);
		add(versionSb);
		add(versionPsych);
		add(versionFnf);

		tipBackground = new FlxSprite();
		tipBackground.scrollFactor.set();
		tipBackground.alpha = 0.7;
		add(tipBackground);

		tipText = new FlxText(0, 0, 0, "");
		tipText.scrollFactor.set();
		switch (ClientPrefs.gameStyle) {
			case 'Psych Engine' | 'Better UI': tipText.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER);
			default: tipText.setFormat("Bahnschrift", 24, FlxColor.WHITE, CENTER);
		}

		tipText.updateHitbox();
		add(tipText);

		tipBackground.makeGraphic(FlxG.width, Std.int((tipTextMargin * 2) + tipText.height), FlxColor.BLACK);

		changeItem();
		tipTextStartScrolling();

		#if android
		addVirtualPad(UP_DOWN, A_B_C_X_Y);
		virtualPad.y = -48;
		#end

		super.create();
	}

	var selectedSomething:Bool = false;

	override function update(elapsed:Float)
	{
		
		if (tipTextScrolling)
		{
			tipText.x -= elapsed * 130;
			if (tipText.x < -tipText.width)
			{
				tipTextScrolling = false;
				tipTextStartScrolling();
				changeTipText();
			}
		}

		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
			if(FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		cameraFollowPosition.setPosition(FlxMath.lerp(cameraFollowPosition.x, cameraFollow.x, lerpVal), FlxMath.lerp(cameraFollowPosition.y, cameraFollow.y, lerpVal));

		if (secretText.visible) {
			secretTextSine += 150 * elapsed;
			secretText.alpha = 1 - Math.sin((Math.PI * secretTextSine) / 150);
		}

		if (galleryText.visible) {
			galleryTextSine += 150 * elapsed;
			galleryText.alpha = 1 - Math.sin((Math.PI * galleryTextSine) / 150);
		}

		if (!selectedSomething)
		{
			if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomething = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleScreenState());
			}

			if (controls.ACCEPT)
			{
				selectedSomething = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));

				if (ClientPrefs.flashing)
					FlxFlicker.flicker(background, 1.1, 0.15, false);

					menuItems.forEach(function(spr:FlxSprite)
					{
						if (currentlySelected != spr.ID)
						{
							FlxTween.tween(spr, {alpha: 0}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween)
								{
									spr.kill();
								}
							});
						}
						else
						{
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
							{
								var daChoice:String = optionSelect[currentlySelected];

						switch (daChoice) {
							case 'story_mode':
								MusicBeatState.switchState(new StoryModeState());
								Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Story Mode";
							case 'freeplay':
								MusicBeatState.switchState(new FreeplayState());
								Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Freeplay Menu";
							#if MODS_ALLOWED
							case 'mods':
								MusicBeatState.switchState(new ModsMenuState());
								Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Mods Menu";
							#end
							case 'credits':
								MusicBeatState.switchState(new CreditsState());
								Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Credits Menu";
							case 'options':
								MusicBeatState.switchState(new options.OptionsState());
								Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Options Menu";
							}
						});
					}
				});
			}
			#if (desktop || android)
			else if (FlxG.keys.anyJustPressed(debugKeys) #if android || virtualPad.buttonC.justPressed #end) {
				selectedSomething = true;
				Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Mod Maker Menu";
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end

			if (FlxG.keys.justPressed.G #if android || virtualPad.buttonX.justPressed #end) {
				selectedSomething = true;
				FlxG.sound.play(Paths.sound('scrollMenu'));
				Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - Gallery Menus";
				MusicBeatState.switchState(new GalleryScreenState());
			}

			if (FlxG.keys.justPressed.S #if android || virtualPad.buttonY.justPressed #end) {
				selectedSomething = true;
				FlxG.sound.play(Paths.sound('scrollMenu'));
				Application.current.window.title = "Friday Night Funkin': SB Engine v" + MainMenuState.sbEngineVersion + " - You are founded a secret!";
				MusicBeatState.switchState(new DVDScreenState());
			}
		}

		super.update(elapsed);

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.screenCenter(X);
		});
	}

	function tipTextStartScrolling()
	{
		tipText.x = tipTextMargin;
		tipText.y = -tipText.height;

		new FlxTimer().start(1.0, function(timer:FlxTimer)
		{
			FlxTween.tween(tipText, {y: tipTextMargin}, 0.3);
			new FlxTimer().start(2.25, function(timer:FlxTimer)
			{
				tipTextScrolling = true;
			});
		});
	}

	function changeTipText() {
		var selectedText:String = '';
		var textArray:Array<String> = CoolUtil.coolTextFile(SUtil.getPath() + Paths.txt('funnyTips'));

		tipText.alpha = 1;
		isTweening = true;
		selectedText = textArray[FlxG.random.int(0, (textArray.length - 1))].replace('--', '\n');
		FlxTween.tween(tipText, {alpha: 0}, 1, {
			ease: FlxEase.linear,
			onComplete: function(freak:FlxTween) {
				if (selectedText != lastString) {
					tipText.text = selectedText;
					lastString = selectedText;
				} else {
					selectedText = textArray[FlxG.random.int(0, (textArray.length - 1))].replace('--', '\n');
					tipText.text = selectedText;
				}

				tipText.alpha = 0;

				FlxTween.tween(tipText, {alpha: 1}, 1, {
					ease: FlxEase.linear,
					onComplete: function(freak:FlxTween) {
						isTweening = false;
					}
				});
			}
		});
	}

	function changeItem(huh:Int = 0)
	{
		currentlySelected += huh;

		if (currentlySelected >= menuItems.length)
			currentlySelected = 0;
		if (currentlySelected < 0)
			currentlySelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == currentlySelected)
			{
				spr.animation.play('selected');
				var add:Float = 0;
				if(menuItems.length > 4) {
					add = menuItems.length * 8;
				}
				cameraFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
				spr.centerOffsets();
			}
		});
	}
}