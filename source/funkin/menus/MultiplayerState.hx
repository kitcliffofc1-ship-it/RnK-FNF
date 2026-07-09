package funkin.menus;

import haxe.Json;
import funkin.backend.FunkinText;

#if sys
import sys.net.Host;
#end

class MultiplayerState extends MusicBeatState
{
	static var SERVER_HOST:String = "127.0.0.1";
	static var SERVER_PORT:Int = 3002;

	var bg:FlxSprite;
	var statusText:FunkinText;

	var navBtns:Array<{txt:FunkinText, hit:FlxSprite, action:Void->Void}> = [];
	var selectedIndex:Int = 0;

	var inputBox:FlxSprite;
	var inputText:FunkinText;
	var codeInput:String = "";
	var isTyping:Bool = false;
	var typingCursor:Float = 0;

	var client:MultiplayerClient;

	override function create()
	{
		super.create();

		DiscordUtil.call("onMenuLoaded", ["Multiplayer"]);

		FlxG.mouse.visible = true;

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		buildPanel();

		statusText = new FunkinText(0, 420, 0, "Press SPACE to connect", 14);
		statusText.screenCenter(X);
		add(statusText);

		client = new MultiplayerClient();
		client.onRoomCreated = onRoomCreated;
		client.onRoomJoined = onRoomJoined;
		client.onError = onServerError;
		client.onRoomClosed = onRoomClosed;

		isTyping = false;
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
		var px = Std.int(FlxG.width / 2 - 180);
		var py = 50;

		var panelBG = new FlxSprite(px, py).makeGraphic(360, 310, 0xCC0A0A1A);
		panelBG.scrollFactor.set();
		add(panelBG);

		var title = new FunkinText(0, py + 12, 0, "MULTIPLAYER", 28);
		title.screenCenter(X);
		title.scrollFactor.set();
		add(title);

		makeTextBtn("[ CREATE ROOM ]", px + 60, py + 60, 22, function() {
			if (!client.connected) { connectToServer(); return; }
			createRoom();
		});

		makeTextBtn("[  JOIN ROOM  ]", px + 65, py + 100, 22, function() {
			if (!client.connected) { connectToServer(); return; }
			startTypingCode();
		});

		var roomLabel = new FunkinText(0, py + 150, 0, "Room Code:", 14);
		roomLabel.screenCenter(X);
		roomLabel.scrollFactor.set();
		add(roomLabel);

		inputBox = new FlxSprite(px + 50, py + 175).makeGraphic(260, 24, 0xFF1A1A2E);
		inputBox.scrollFactor.set();
		inputBox.visible = false;
		add(inputBox);

		inputText = new FunkinText(0, py + 177, 0, "", 18);
		inputText.screenCenter(X);
		inputText.scrollFactor.set();
		inputText.visible = false;
		add(inputText);

		var hintText = new FunkinText(0, py + 210, 0, "Type code, ENTER to join", 12);
		hintText.screenCenter(X);
		hintText.scrollFactor.set();
		hintText.visible = false;
		add(hintText);

		makeTextBtn("[ BACK ]", px + 20, py + 260, 16, function() {
			if (client != null) client.disconnect();
			FlxG.switchState(new MainMenuState());
		});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (client != null && client.connected)
			client.update(elapsed);

		if (controls.BACK)
		{
			if (isTyping)
			{
				isTyping = false;
				inputBox.visible = false;
				inputText.visible = false;
				showHint(false);
			}
			else
			{
				if (client != null) client.disconnect();
				FlxG.switchState(new MainMenuState());
			}
		}

		if (isTyping)
		{
			typingCursor += elapsed;

			var keyStr:String = getTypedKey();
			if (keyStr != null && codeInput.length < 6)
			{
				codeInput += keyStr;
				FlxG.sound.play(Paths.sound(Flags.DEFAULT_EDITOR_TEXTTYPE_SOUND));
			}

			if (FlxG.keys.justPressed.BACKSPACE && codeInput.length > 0)
			{
				codeInput = codeInput.substr(0, codeInput.length - 1);
				FlxG.sound.play(Paths.sound(Flags.DEFAULT_EDITOR_TEXTREMOVE_SOUND));
			}

			if (FlxG.keys.justPressed.ENTER && codeInput.length >= 4)
			{
				isTyping = false;
				inputBox.visible = false;
				inputText.visible = false;
				showHint(false);
				joinRoom(codeInput);
			}

			inputText.text = codeInput + ((Math.floor(typingCursor * 2) % 2 == 0) ? "|" : " ");
			inputText.screenCenter(X);
			return;
		}

		for (i in 0...navBtns.length)
			navBtns[i].txt.alpha = (i == selectedIndex) ? 1.0 : 0.5;

		if (FlxG.mouse.justPressed)
		{
			for (b in navBtns)
				if (FlxG.mouse.overlaps(b.hit)) { b.action(); break; }
		}

		if (FlxG.keys.justPressed.UP && selectedIndex > 0)
			selectedIndex--;
		else if (FlxG.keys.justPressed.DOWN && selectedIndex < navBtns.length - 1)
			selectedIndex++;

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			navBtns[selectedIndex].action();
	}

	function connectToServer()
	{
		#if sys
		statusText.text = "Connecting...";
		if (client.connect(SERVER_HOST, SERVER_PORT))
			statusText.text = "Connected!";
		else
			statusText.text = "Failed to connect! Check if server is running";
		#end
	}

	function createRoom()
	{
		if (!client.connected)
		{
			statusText.text = "Not connected! Press SPACE to connect";
			return;
		}
		statusText.text = "Creating room...";
		client.send("create_room", {name: "RnK Room"});
	}

	function startTypingCode()
	{
		if (!client.connected)
		{
			statusText.text = "Not connected! Press SPACE to connect";
			return;
		}
		isTyping = true;
		codeInput = "";
		typingCursor = 0;
		inputBox.visible = true;
		inputText.visible = true;
		showHint(true);
	}

	function showHint(show:Bool)
	{
		for (m in members)
		{
			if (Std.isOfType(m, FunkinText))
			{
				var ft:FunkinText = cast m;
				if (ft.text == "Type code, ENTER to join")
					ft.visible = show;
			}
		}
	}

	function joinRoom(code:String)
	{
		statusText.text = 'Joining room $code...';
		client.send("join_room", {roomId: code.toUpperCase()});
	}

	function onRoomCreated()
	{
		statusText.text = 'Room created: ${client.roomId}';
		var state = new MultiplayerLobbyState();
		state.client = client;
		FlxG.switchState(state);
	}

	function onRoomJoined()
	{
		statusText.text = 'Joined room ${client.roomId}';
		var state = new MultiplayerLobbyState();
		state.client = client;
		FlxG.switchState(state);
	}

	function onServerError(msg:String)
	{
		statusText.text = 'Error: $msg';
	}

	function onRoomClosed()
	{
		statusText.text = "Room closed";
	}

	function getTypedKey():String
	{
		var k = FlxG.keys;
		if (k.justPressed.A) return "A"; if (k.justPressed.B) return "B";
		if (k.justPressed.C) return "C"; if (k.justPressed.D) return "D";
		if (k.justPressed.E) return "E"; if (k.justPressed.F) return "F";
		if (k.justPressed.G) return "G"; if (k.justPressed.H) return "H";
		if (k.justPressed.I) return "I"; if (k.justPressed.J) return "J";
		if (k.justPressed.K) return "K"; if (k.justPressed.L) return "L";
		if (k.justPressed.M) return "M"; if (k.justPressed.N) return "N";
		if (k.justPressed.O) return "O"; if (k.justPressed.P) return "P";
		if (k.justPressed.Q) return "Q"; if (k.justPressed.R) return "R";
		if (k.justPressed.S) return "S"; if (k.justPressed.T) return "T";
		if (k.justPressed.U) return "U"; if (k.justPressed.V) return "V";
		if (k.justPressed.W) return "W"; if (k.justPressed.X) return "X";
		if (k.justPressed.Y) return "Y"; if (k.justPressed.Z) return "Z";
		if (k.justPressed.ZERO) return "0"; if (k.justPressed.ONE) return "1";
		if (k.justPressed.TWO) return "2"; if (k.justPressed.THREE) return "3";
		if (k.justPressed.FOUR) return "4"; if (k.justPressed.FIVE) return "5";
		if (k.justPressed.SIX) return "6"; if (k.justPressed.SEVEN) return "7";
		if (k.justPressed.EIGHT) return "8"; if (k.justPressed.NINE) return "9";
		return null;
	}
}
