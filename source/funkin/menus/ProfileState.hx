package funkin.menus;

import funkin.backend.FunkinText;

class ProfileState extends MusicBeatState
{
	var bg:FlxSprite;
	var txt:FunkinText;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Profile"]);

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		txt = new FunkinText(0, 0, 0, "Profile - Coming Soon", 48);
		txt.screenCenter();
		add(txt);

		var backText = new FunkinText(0, FlxG.height - 40, 0, "Press ESC to go back", 24);
		backText.screenCenter(X);
		add(backText);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.BACK)
			FlxG.switchState(new MainMenuState());
	}
}
