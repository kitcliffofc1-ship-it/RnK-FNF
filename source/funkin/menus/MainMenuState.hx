package funkin.menus;

import flixel.FlxState;
import flixel.effects.FlxFlicker;
import flixel.tweens.FlxTween;
import funkin.backend.FunkinText;
import funkin.backend.scripting.events.menu.MenuChangeEvent;
import funkin.backend.scripting.events.NameEvent;
import funkin.menus.credits.CreditsMain;
import funkin.options.OptionsMenu;
import funkin.menus.MultiplayerState;
import funkin.menus.DownloadState;
import funkin.menus.ProfileState;
import lime.app.Application;

using StringTools;

class MainMenuState extends MusicBeatState
{
	var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var menuTexts:FlxTypedGroup<FunkinText>;

	var optionShit:Array<String> = CoolUtil.coolTextFile(Paths.txt("config/menuItems"));

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var versionText:FunkinText;

	var devModeWarning:FunkinText;

	public var canAccessDebugMenus:Bool = !Flags.DISABLE_EDITORS;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Main Menu"]);

		CoolUtil.playMenuSong();

		bg = new FlxSprite(-80).loadAnimatedGraphic(Paths.image('menus/menuBG'));
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadAnimatedGraphic(Paths.image('menus/menuDesat'));
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		for(bg in [bg, magenta]) {
			bg.scrollFactor.set(0, 0.18);
			bg.scale.set(1.15, 1.15);
			bg.updateHitbox();
			bg.screenCenter();
			bg.antialiasing = true;
		}

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);
		menuTexts = new FlxTypedGroup<FunkinText>();
		add(menuTexts);

		for (i=>option in optionShit)
		{
			var yPos:Float = 30 + (i * 110);
			var menuItem:FlxSprite = new FlxSprite(30, yPos);
			var hasGFX:Bool = false;

			try
			{
				menuItem.frames = Paths.getFrames('menus/mainmenu/${option}');
				menuItem.animation.addByPrefix('idle', option + " basic", 24);
				menuItem.animation.addByPrefix('selected', option + " white", 24);
				menuItem.animation.play('idle');
				menuItem.scale.set(0.6, 0.6);
				menuItem.updateHitbox();
				hasGFX = true;
			}
			catch (e:Dynamic) {}

			if (!hasGFX)
			{
				menuItem.makeGraphic(280, 50, 0x88000000);
				var txt = new FunkinText(35, yPos + 10, 270, option.toUpperCase(), 24);
				txt.ID = i;
				txt.scrollFactor.set();
				menuTexts.add(txt);
			}

			menuItem.ID = i;
			menuItems.add(menuItem);
			menuItem.scrollFactor.set();
			menuItem.antialiasing = true;
		}

		FlxG.camera.follow(camFollow, null, 0.06);

		versionText = new FunkinText(5, FlxG.height - 2, 0, [
			Flags.VERSION_MESSAGE,
			TU.translate("mainMenu.commit", [Flags.COMMIT_NUMBER, Flags.COMMIT_HASH]),
			TU.translate("mainMenu.openMods", [controls.getKeyName(SWITCHMOD)]),
			''
		].join('\n'));
		versionText.y -= versionText.height;
		versionText.scrollFactor.set();
		add(versionText);

		changeItem();

		devModeWarning = new FunkinText(0, FlxG.height - 50, 1280, "You have to enable DEVELOPER MODE in the miscellaneous settings!", 24);
		devModeWarning.alignment = CENTER;
		add(devModeWarning);
		devModeWarning.scrollFactor.set();
		devModeWarning.alpha = 0;
	}

	var selectedSomethin:Bool = false;
	var forceCenterX:Bool = false;
	var devModeCount:Int = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!selectedSomethin)
		{
			if (canAccessDebugMenus) {
				if (controls.DEV_ACCESS) {
					persistentUpdate = false;
					persistentDraw = true;
					openSubState(new funkin.editors.EditorPicker());
				}
			}
			if (!Options.devMode && FlxG.keys.justPressed.SEVEN) {
				FlxG.sound.play(Paths.sound(Flags.DEFAULT_EDITOR_DELETE_SOUND));
				if (devModeCount++ == 2) {
					FlxTween.tween(devModeWarning, {alpha: 1}, 0.4);
				}
				FlxTween.completeTweensOf(devModeWarning);
				FlxTween.color(devModeWarning, 0.2, 0xFFFF0000, 0xFFFFFFFF);
				FlxTween.shake(devModeWarning, 0.005, 0.3);
				devModeWarning.y = FlxG.height - 75;
				FlxTween.tween(devModeWarning, {y: FlxG.height - 50}, 0.4);
			}

			var upP = controls.UP_P;
			var downP = controls.DOWN_P;
			var scroll = FlxG.mouse.wheel;

			if (upP || downP || scroll != 0)
				changeItem((upP ? -1 : 0) + (downP ? 1 : 0) - scroll);

			if (controls.BACK)
				FlxG.switchState(new TitleState());

			#if MOD_SUPPORT
			if (controls.SWITCHMOD) {
				openSubState(new ModSwitchMenu());
				persistentUpdate = false;
				persistentDraw = true;
			}
			#end

			if (controls.ACCEPT)
				selectItem();
		}

		super.update(elapsed);

		if (forceCenterX)
		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.screenCenter(X);
		});
	}

	public override function switchTo(nextState:FlxState):Bool {
		try {
			menuItems.forEach(function(spr:FlxSprite) {
				FlxTween.tween(spr, {alpha: 0}, 0.5, {ease: FlxEase.quintOut});
			});
			menuTexts.forEach(function(txt:FunkinText) {
				FlxTween.tween(txt, {alpha: 0}, 0.5, {ease: FlxEase.quintOut});
			});
		}
		return super.switchTo(nextState);
	}

	function selectItem() {
		selectedSomethin = true;
		CoolUtil.playMenuSFX(CONFIRM);

		if (Options.flashingMenu) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

		FlxFlicker.flicker(menuItems.members[curSelected], 1, Options.flashingMenu ? 0.06 : 0.15, false, false, function(flick:FlxFlicker)
		{
			var daChoice:String = optionShit[curSelected];

			var event = event("onSelectItem", EventManager.get(NameEvent).recycle(daChoice));
			if (event.cancelled) return;
			switch (event.name)
			{
			case 'story mode': FlxG.switchState(new StoryMenuState());
			case 'multiplayer': FlxG.switchState(new MultiplayerState());
			case 'freeplay': FlxG.switchState(new FreeplayState());
			case 'profile': FlxG.switchState(new ProfileState());
			case 'download': FlxG.switchState(new DownloadState());
			case 'donate', 'credits': FlxG.switchState(new CreditsMain());
			case 'options': FlxG.switchState(new OptionsMenu());
			}
		});
	}
	function changeItem(huh:Int = 0)
	{
		var event = event("onChangeItem", EventManager.get(MenuChangeEvent).recycle(curSelected, FlxMath.wrap(curSelected + huh, 0, menuItems.length-1), huh, huh != 0));
		if (event.cancelled) return;

		curSelected = event.value;

		if (event.playMenuSFX)
			CoolUtil.playMenuSFX(SCROLL, 0.7);

		menuItems.forEach(function(spr:FlxSprite)
		{
			if (spr.animation.exists('idle'))
				spr.animation.play('idle');
			spr.alpha = 0.6;

			if (spr.ID == curSelected)
			{
				if (spr.animation.exists('selected'))
					spr.animation.play('selected');
				spr.alpha = 1.0;
				var mid = spr.getGraphicMidpoint();
				camFollow.setPosition(mid.x, mid.y);
				mid.put();
			}

			if (spr.animation.exists('idle'))
			{
				spr.updateHitbox();
				spr.centerOffsets();
			}
		});

		menuTexts.forEach(function(txt:FunkinText)
		{
			txt.alpha = 0.6;
			if (txt.ID == curSelected)
			{
				txt.alpha = 1.0;
				txt.scale.set(1.1, 1.1);
			}
			else
			{
				txt.scale.set(1.0, 1.0);
			}
		});
	}
}
