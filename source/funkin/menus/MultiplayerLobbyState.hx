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
	var readyBtn:FunkinText;
	var leaveBtn:FunkinText;
	var startBtn:FunkinText;
	var botBtn:FunkinText;

	var isReady:Bool = false;
	var botCount:Int = 0;
	var selectedIndex:Int = 0;
	var lobbyNavItems:Array<{txt:FunkinText, action:Void->Void}> = [];

	var panelBG:FlxSprite;

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

	function buildPanel()
	{
		var px = Std.int(FlxG.width / 2 - 200);
		var py = 30;
		var pw = 400;
		var ph = 400;

		panelBG = new FlxSprite(px, py).makeGraphic(pw, ph, 0xCC0A0A1A);
		panelBG.scrollFactor.set();
		add(panelBG);

		function addBorder(c, xOff, yOff) {
			var t = new FunkinText(px + xOff, py + yOff, 0, c, 10);
			t.scrollFactor.set();
			add(t);
		}

		addBorder("╔══════════════════════════════════════╗", 5, 5);

		var roomCodeText = new FunkinText(px + 10, py + 8, 0, 'ROOM: ${client.roomId}', 24);
		roomCodeText.scrollFactor.set();
		add(roomCodeText);

		addBorder("╠══════════════════════════════════════╣", 5, 35);

		var slotY = [55, 115, 175];
		for (i in 0...3)
		{
			addBorder("║                                      ║", 5, slotY[i] - 5);
			var nameTxt = new FunkinText(px + 15, py + slotY[i], 0, "Empty Slot", 16);
			nameTxt.scrollFactor.set();
			add(nameTxt);

			var statusTxt = new FunkinText(px + 15, py + slotY[i] + 28, 0, "", 13);
			statusTxt.scrollFactor.set();
			add(statusTxt);

			playerSlots.push({nameTxt: nameTxt, statusTxt: statusTxt});
		}

		addBorder("╠══════════════════════════════════════╣", 5, 215);

		addBorder("║                                      ║", 5, 225);
		addBorder("║                                      ║", 5, 255);

		var songLabel = new FunkinText(px + 15, py + 228, 0, "Song: Concerned", 15);
		songLabel.scrollFactor.set();
		add(songLabel);

		var modeLabel = new FunkinText(px + 15, py + 258, 0, "Mode: 3 Player Battle", 15);
		modeLabel.scrollFactor.set();
		add(modeLabel);

		addBorder("╚══════════════════════════════════════╝", 5, 290);

		readyBtn = new FunkinText(px + 10, py + 310, 0, "[  READY  ]", 18);
		readyBtn.scrollFactor.set();
		add(readyBtn);

		botBtn = new FunkinText(px + 10, py + 340, 0, "[ ADD BOT ]", 18);
		botBtn.scrollFactor.set();
		botBtn.visible = client.hostId == client.playerId;
		add(botBtn);

		startBtn = new FunkinText(px + 10, py + 340, 0, "[ START GAME ]", 20);
		startBtn.scrollFactor.set();
		startBtn.visible = false;
		add(startBtn);

		leaveBtn = new FunkinText(px + 10, py + 370, 0, "[ LEAVE ]", 16);
		leaveBtn.scrollFactor.set();
		add(leaveBtn);

		statusText = new FunkinText(px + 10, py + 395, pw - 20, "Waiting for players...", 12);
		statusText.scrollFactor.set();
		add(statusText);

		lobbyNavItems = [
			{txt: readyBtn, action: toggleReady},
			{txt: botBtn, action: addBot},
			{txt: startBtn, action: forceStart},
			{txt: leaveBtn, action: leaveRoom}
		];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (client != null)
			client.update(elapsed);

		updateLobbyNav();

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(readyBtn))
				toggleReady();
			else if (FlxG.mouse.overlaps(leaveBtn))
				leaveRoom();
			else if (botBtn.visible && FlxG.mouse.overlaps(botBtn))
				addBot();
			else if (startBtn.visible && FlxG.mouse.overlaps(startBtn))
				forceStart();
		}

		if (controls.BACK)
			leaveRoom();

		if (FlxG.keys.justPressed.UP && selectedIndex > 0)
			selectedIndex--;
		else if (FlxG.keys.justPressed.DOWN && selectedIndex < lobbyNavItems.length - 1)
			selectedIndex++;

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			var item = lobbyNavItems[selectedIndex];
			if (item.txt.visible)
				item.action();
		}
	}

	function updateLobbyNav()
	{
		for (i in 0...lobbyNavItems.length)
		{
			var item = lobbyNavItems[i];
			item.txt.alpha = (item.txt.visible && i == selectedIndex) ? 1.0 : (item.txt.visible ? 0.5 : 0.2);
		}
	}

	function addBot()
	{
		if (botCount >= 2 || client.players.length + botCount >= 3) return;
		botCount++;
		botBtn.text = '[ ADD BOT ($botCount/2) ]';
		updatePlayers();
	}

	function forceStart()
	{
		var totalPlayers = client.players.length + botCount;
		if (totalPlayers < 2) return;
		statusText.text = "Starting with bots...";
		startGameNow();
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
		readyBtn.text = isReady ? "[ UNREADY ]" : "[  READY  ]";
		updatePlayers();
	}

	function leaveRoom()
	{
		client.send("leave_room");
		client.disconnect();
		FlxG.switchState(new MultiplayerState());
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

		if (allReady && client.hostId == client.playerId)
		{
			startBtn.visible = true;
			botBtn.visible = false;
		}
		else
		{
			startBtn.visible = false;
			if (client.hostId == client.playerId)
				botBtn.visible = true;
		}
	}

	function onPlayersUpdated()
	{
		updatePlayers();
	}

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
