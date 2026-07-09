package funkin.menus;

import funkin.backend.FunkinText;
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

	var navBtns:Array<{txt:FunkinText, hit:FlxSprite, action:Void->Void}> = [];
	var selectedIndex:Int = 0;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Multiplayer Lobby"]);

		FlxG.mouse.visible = true;

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		buildPanel();

		client.onPlayersUpdated = onPlayersUpdated;
		client.onGameStarting = onGameStarting;
		client.onGameStart = onGameStart;
		client.onRoomClosed = onRoomClosed;

		updatePlayers();
	}

	function makeTextBtn(txt:String, x:Float, y:Float, size:Int, action:Void->Void)
	{
		var t = new FunkinText(x, y, 0, txt, size);
		t.scrollFactor.set();
		add(t);

		var h = new FlxSprite(t.x - 4, t.y - 4).makeGraphic(Std.int(t.width + 8), Std.int(t.height + 8), 0x00FFFFFF);
		h.scrollFactor.set();
		add(h);

		navBtns.push({txt: t, hit: h, action: action});
	}

	function buildPanel()
	{
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

		makeTextBtn("[  READY  ]", px + 10, py + 300, 18, toggleReady);

		makeTextBtn("[ ADD BOT ]", px + 10, py + 330, 18, function() {
			if (botCount >= 2 || client.players.length + botCount >= 3) return;
			botCount++;
			navBtns[2].txt.text = '[ ADD BOT ($botCount/2) ]';
			updatePlayers();
		});

		makeTextBtn("[ START GAME ]", px + 10, py + 330, 20, function() {
			var totalPlayers = client.players.length + botCount;
			if (totalPlayers < 2) return;
			statusText.text = "Starting with bots...";
			startGameNow();
		});

		makeTextBtn("[ LEAVE ]", px + 10, py + 370, 16, function() {
			client.send("leave_room");
			client.disconnect();
			FlxG.switchState(new MultiplayerState());
		});

		statusText = new FunkinText(px + 10, py + 395, 380, "Waiting for players...", 12);
		statusText.scrollFactor.set();
		add(statusText);

		showStartBtn(false);
	}

	function showStartBtn(show:Bool)
	{
		// start btn index 3, bot btn index 2
		if (navBtns.length >= 4)
		{
			navBtns[3].txt.visible = navBtns[3].hit.visible = show;
			navBtns[2].txt.visible = navBtns[2].hit.visible = !show;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (client != null)
			client.update(elapsed);

		for (i in 0...navBtns.length)
			navBtns[i].txt.alpha = (navBtns[i].hit.visible && i == selectedIndex) ? 1.0 : (navBtns[i].hit.visible ? 0.5 : 0.2);

		if (FlxG.mouse.justPressed)
		{
			for (b in navBtns)
				if (b.hit.visible && FlxG.mouse.overlaps(b.hit)) { b.action(); break; }
		}

		if (controls.BACK)
		{
			client.send("leave_room");
			client.disconnect();
			FlxG.switchState(new MultiplayerState());
		}

		if (FlxG.keys.justPressed.UP && selectedIndex > 0)
		{
			selectedIndex--;
			while (selectedIndex > 0 && !navBtns[selectedIndex].hit.visible) selectedIndex--;
		}
		else if (FlxG.keys.justPressed.DOWN && selectedIndex < navBtns.length - 1)
		{
			selectedIndex++;
			while (selectedIndex < navBtns.length - 1 && !navBtns[selectedIndex].hit.visible) selectedIndex++;
		}

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			if (navBtns[selectedIndex].hit.visible) navBtns[selectedIndex].action();
	}

	function startGameNow()
	{
		MultiplayerPlayState.mpClient = client;
		MultiplayerPlayState.botCount = botCount;
		PlayState.__loadSong("cornered", "hard", null);
		FlxG.switchState(new MultiplayerPlayState());
	}

	function toggleReady()
	{
		isReady = !isReady;
		client.send("player_ready", {ready: isReady});
		navBtns[0].txt.text = isReady ? "[ UNREADY ]" : "[  READY  ]";
		updatePlayers();
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

	function onGameStarting(countdown:Int)
	{
		statusText.text = 'Game starting in $countdown...';
	}

	function onGameStart(startTime:Float)
	{
		statusText.text = "GO!";
		startGameNow();
	}

	function onRoomClosed()
	{
		statusText.text = "Room closed";
		client.disconnect();
		FlxG.switchState(new MultiplayerState());
	}
}
