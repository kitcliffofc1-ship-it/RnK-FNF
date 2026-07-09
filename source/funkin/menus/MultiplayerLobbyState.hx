package funkin.menus;

import funkin.backend.FunkinText;
import funkin.game.MultiplayerPlayState;
import funkin.game.PlayState;

class MultiplayerLobbyState extends MusicBeatState
{
	public var client:MultiplayerClient;

	var bg:FlxSprite;
	var roomCodeText:FunkinText;
	var playerSlots:Array<LobbyPlayerSlot> = [];
	var readyBtn:FlxSprite;
	var readyLabel:FunkinText;
	var startBtn:FlxSprite;
	var startLabel:FunkinText;
	var leaveBtn:FlxSprite;
	var statusText:FunkinText;
	var isReady:Bool = false;

	var botCount:Int = 0;
	var botBtn:FlxSprite;
	var botLabel:FunkinText;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Multiplayer Lobby"]);

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		roomCodeText = new FunkinText(0, 20, 0, 'ROOM: ${client.roomId}', 32);
		roomCodeText.screenCenter(X);
		add(roomCodeText);

		for (i in 0...3)
		{
			var slot = new LobbyPlayerSlot(80 + i * 130);
			playerSlots.push(slot);
			add(slot.bg);
			add(slot.nameText);
			add(slot.statusText);
		}

		statusText = new FunkinText(0, 470, 0, "Waiting for players...", 18);
		statusText.screenCenter(X);
		add(statusText);

		readyBtn = new FlxSprite(0, 510).makeGraphic(180, 40, 0xFF4CAF50);
		readyBtn.screenCenter(X);
		add(readyBtn);
		readyLabel = new FunkinText(0, 518, 180, "READY", 20);
		readyLabel.screenCenter(X);
		readyLabel.alignment = CENTER;
		add(readyLabel);

		leaveBtn = new FlxSprite(0, 560).makeGraphic(180, 40, 0xFFF44336);
		leaveBtn.screenCenter(X);
		add(leaveBtn);
		var leaveLabel = new FunkinText(0, 568, 180, "LEAVE ROOM", 20);
		leaveLabel.screenCenter(X);
		leaveLabel.alignment = CENTER;
		add(leaveLabel);

		botBtn = new FlxSprite(0, 600).makeGraphic(180, 40, 0xFF9C27B0);
		botBtn.screenCenter(X);
		botBtn.visible = client.hostId == client.playerId;
		add(botBtn);
		botLabel = new FunkinText(0, 608, 180, "ADD BOT", 20);
		botLabel.screenCenter(X);
		botLabel.alignment = CENTER;
		botLabel.visible = client.hostId == client.playerId;
		add(botLabel);

		client.onPlayersUpdated = onPlayersUpdated;
		client.onGameStarting = onGameStarting;
		client.onGameStart = onGameStart;
		client.onRoomClosed = onRoomClosed;

		updatePlayers();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (client != null)
			client.update(elapsed);

		if (FlxG.mouse.justPressed)
		{
			var mp = FlxG.mouse.getScreenPosition();

			if (readyBtn.overlapsPoint(mp))
				toggleReady();
			else if (leaveBtn.overlapsPoint(mp))
				leaveRoom();
			else if (botBtn.visible && botBtn.overlapsPoint(mp))
				addBot();
			else if (startBtn != null && startLabel.visible && startBtn.overlapsPoint(mp))
				forceStart();
		}

		if (controls.BACK)
			leaveRoom();
	}

	function addBot()
	{
		if (botCount >= 2 || client.players.length + botCount >= 3) return;
		botCount++;
		botLabel.text = 'ADD BOT ($botCount/2)';
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
		PlayState.__loadSong("tutorial", "normal", null);
		FlxG.switchState(new MultiplayerPlayState());
	}

	function toggleReady()
	{
		isReady = !isReady;
		client.send("player_ready", {ready: isReady});
		readyLabel.text = isReady ? "UNREADY" : "READY";
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
			if (i < players.length)
			{
				var p = players[i];
				playerSlots[i].bg.visible = true;
				playerSlots[i].nameText.text = p.name;
				playerSlots[i].nameText.visible = true;
				playerSlots[i].nameText.alpha = 1;
				playerSlots[i].statusText.text = p.ready ? "READY" : "WAITING...";
				playerSlots[i].statusText.visible = true;
				playerSlots[i].bg.color = p.isHost ? 0xFFFFD700 : (p.id.startsWith("bot_") ? 0xFF9C27B0 : 0xFF333333);
			}
			else
			{
				playerSlots[i].bg.visible = true;
				playerSlots[i].nameText.text = "Empty Slot";
				playerSlots[i].nameText.alpha = 0.4;
				playerSlots[i].statusText.text = "";
			}
		}

		var allReady = players.length >= 2;
		for (p in players)
			if (!p.ready) allReady = false;

		if (allReady && client.hostId == client.playerId)
		{
			if (startBtn == null)
			{
				startBtn = new FlxSprite(0, 420).makeGraphic(180, 40, 0xFFFF9800);
				startBtn.screenCenter(X);
				add(startBtn);
				startLabel = new FunkinText(0, 428, 180, "START GAME", 20);
				startLabel.screenCenter(X);
				startLabel.alignment = CENTER;
				add(startLabel);
			}
			startBtn.visible = startLabel.visible = true;
		}
		else if (startBtn != null)
		{
			startBtn.visible = startLabel.visible = false;
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

class LobbyPlayerSlot
{
	public var bg:FlxSprite;
	public var nameText:FunkinText;
	public var statusText:FunkinText;

	public function new(y:Float)
	{
		bg = new FlxSprite(0, y).makeGraphic(200, 100, 0xFF333333);
		bg.screenCenter(X);

		nameText = new FunkinText(0, y + 20, 200, "", 18);
		nameText.screenCenter(X);
		nameText.alignment = CENTER;

		statusText = new FunkinText(0, y + 55, 200, "", 16);
		statusText.screenCenter(X);
		statusText.alignment = CENTER;
	}
}
