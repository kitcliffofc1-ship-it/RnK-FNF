package funkin.menus;

import funkin.backend.FunkinText;
import flixel.util.FlxTimer;
import funkin.game.MultiplayerPlayState;
import funkin.game.PlayState;

class MultiplayerLobbyState extends MusicBeatState
{
	public var client:MultiplayerClient;

	var bg:FlxSprite;
	var statusText:FunkinText;
	var playerSlots:Array<{nameTxt:FunkinText, statusTxt:FunkinText}> = [];

	var isReady:Bool = false;
	var botCount:Int = 0;

	var btnTexts:Array<FunkinText> = [];
	var selectedIndex:Int = 0;
	var inputReady:Bool = false;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Multiplayer Lobby"]);

		new FlxTimer().start(0.05, function(_) inputReady = true);

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		var px = Std.int(FlxG.width / 2 - 200);
		var py = 30;

		var panelBG = new FlxSprite(px, py).makeGraphic(400, 420, 0xCC0A0A1A);
		panelBG.scrollFactor.set();
		add(panelBG);

		var roomText = new FunkinText(px + 10, py + 8, 0, 'ROOM: ${client.roomId}', 24);
		roomText.scrollFactor.set();
		add(roomText);

		var slotY = [55, 115, 175];
		for (i in 0...3)
		{
			var nameTxt = new FunkinText(px + 15, py + slotY[i], 0, "Empty Slot", 16);
			nameTxt.scrollFactor.set();
			add(nameTxt);

			var statusTxt = new FunkinText(px + 15, py + slotY[i] + 28, 0, "", 13);
			statusTxt.scrollFactor.set();
			add(statusTxt);

			playerSlots.push({nameTxt: nameTxt, statusTxt: statusTxt});
		}

		var sep = new FunkinText(px + 10, py + 215, 0, "────────────────────────────────────", 8);
		sep.scrollFactor.set();
		add(sep);

		var songTxt = new FunkinText(px + 15, py + 228, 0, "Song: Concerned", 15);
		songTxt.scrollFactor.set();
		add(songTxt);

		var modeTxt = new FunkinText(px + 15, py + 258, 0, "Mode: 3 Player Battle", 15);
		modeTxt.scrollFactor.set();
		add(modeTxt);

		function addBtn(txt:String, x:Float, y:Float, size:Int) {
			var t = new FunkinText(x, y, 0, txt, size);
			t.scrollFactor.set();
			add(t);
			btnTexts.push(t);
			return t;
		}

		// indices: 0=ready, 1=bot, 2=start, 3=leave
		addBtn("[  READY  ]", px + 10, py + 300, 18);
		addBtn("[ ADD BOT ]", px + 10, py + 330, 18);
		addBtn("[ START GAME ]", px + 10, py + 330, 20);
		addBtn("[ LEAVE ]", px + 10, py + 370, 16);

		statusText = new FunkinText(px + 10, py + 395, 380, "Waiting for players...", 12);
		statusText.scrollFactor.set();
		add(statusText);

		client.onPlayersUpdated = onPlayersUpdated;
		client.onGameStarting = onGameStarting;
		client.onGameStart = onGameStart;
		client.onRoomClosed = onRoomClosed;

		updatePlayers();
	}

	function showStartBtn(show:Bool)
	{
		if (btnTexts.length < 4) return;
		btnTexts[1].visible = !show; // bot
		btnTexts[2].visible = show;  // start
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (client != null)
			client.update(elapsed);

		if (!inputReady) return;

		for (i in 0...btnTexts.length)
			btnTexts[i].alpha = (btnTexts[i].visible && i == selectedIndex) ? 1.0 : (btnTexts[i].visible ? 0.5 : 0.2);

		if (controls.BACK)
		{
			client.send("leave_room");
			client.disconnect();
			FlxG.switchState(new MultiplayerState());
		}

		if (FlxG.keys.justPressed.UP)
		{
			selectedIndex--;
			if (selectedIndex < 0) selectedIndex = 0;
			while (selectedIndex > 0 && !btnTexts[selectedIndex].visible) selectedIndex--;
		}
		else if (FlxG.keys.justPressed.DOWN)
		{
			selectedIndex++;
			if (selectedIndex >= btnTexts.length) selectedIndex = btnTexts.length - 1;
			while (selectedIndex < btnTexts.length - 1 && !btnTexts[selectedIndex].visible) selectedIndex++;
		}

		if ((FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) && selectedIndex >= 0 && selectedIndex < btnTexts.length)
		{
			if (!btnTexts[selectedIndex].visible) return;
			switch (selectedIndex)
			{
				case 0:
					isReady = !isReady;
					client.send("player_ready", {ready: isReady});
					btnTexts[0].text = isReady ? "[ UNREADY ]" : "[  READY  ]";
					updatePlayers();
				case 1:
					if (botCount >= 2 || client.players.length + botCount >= 3) return;
					botCount++;
					btnTexts[1].text = '[ ADD BOT ($botCount/2) ]';
					updatePlayers();
				case 2:
					var totalPlayers = client.players.length + botCount;
					if (totalPlayers < 2) return;
					statusText.text = "Starting with bots...";
					startGameNow();
				case 3:
					client.send("leave_room");
					client.disconnect();
					FlxG.switchState(new MultiplayerState());
			}
		}
	}

	function startGameNow()
	{
		MultiplayerPlayState.mpClient = client;
		MultiplayerPlayState.botCount = botCount;
		PlayState.__loadSong("cornered", "hard", null);
		FlxG.switchState(new MultiplayerPlayState());
	}

	function updatePlayers()
	{
		var players = client.players.copy();
		for (j in 0...botCount)
			players.push({id: 'bot_$j', name: 'Bot ${j+1}', ready: true, isHost: false});

		for (i in 0...3)
		{
			var slot = playerSlots[i];
			if (i < players.length)
			{
				var p = players[i];
				slot.nameTxt.text = p.name;
				slot.nameTxt.alpha = 1;
				slot.statusTxt.text = p.ready ? "> READY ✓" : "> WAIT...";
				slot.statusTxt.visible = true;
			}
			else
			{
				slot.nameTxt.text = "Empty Slot";
				slot.nameTxt.alpha = 0.4;
				slot.statusTxt.text = "";
			}
		}

		var allReady = players.length >= 2;
		for (p in players)
			if (!p.ready) allReady = false;

		showStartBtn(allReady && client.hostId == client.playerId);
	}

	function onPlayersUpdated() { updatePlayers(); }
	function onGameStarting(countdown:Int) { statusText.text = 'Game starting in $countdown...'; }
	function onGameStart(startTime:Float) { statusText.text = "GO!"; startGameNow(); }
	function onRoomClosed() { statusText.text = "Room closed"; client.disconnect(); FlxG.switchState(new MultiplayerState()); }
}
