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
	var titleText:FunkinText;
	var statusText:FunkinText;

	var createRoomBtn:FlxSprite;
	var joinRoomBtn:FlxSprite;
	var backBtn:FlxSprite;

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

		bg = new FlxSprite().loadAnimatedGraphic(Paths.image('menus/menuBGBlue'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		titleText = new FunkinText(0, 30, 0, "MULTIPLAYER", 40);
		titleText.screenCenter(X);
		add(titleText);

		statusText = new FunkinText(0, 80, 0, "Press SPACE to connect", 20);
		statusText.screenCenter(X);
		add(statusText);

		createRoomBtn = createButton(120, "CREATE ROOM", 0xFF4CAF50);
		add(createRoomBtn);

		joinRoomBtn = createButton(200, "JOIN ROOM", 0xFF2196F3);
		add(joinRoomBtn);

		backBtn = createButton(FlxG.height - 60, "BACK", 0xFFF44336);
		add(backBtn);

		inputBox = new FlxSprite(0, 280).makeGraphic(300, 40, 0xFF333333);
		inputBox.screenCenter(X);
		inputBox.visible = false;
		add(inputBox);

		inputText = new FunkinText(0, 288, 300, "", 20);
		inputText.screenCenter(X);
		inputText.visible = false;
		add(inputText);

		var hintText = new FunkinText(0, 325, 0, "Type room code, press ENTER to join", 14);
		hintText.screenCenter(X);
		hintText.visible = false;
		add(hintText);

		client = new MultiplayerClient();
		client.onRoomCreated = onRoomCreated;
		client.onRoomJoined = onRoomJoined;
		client.onError = onServerError;
		client.onRoomClosed = onRoomClosed;

		isTyping = false;
	}

	function createButton(y:Float, label:String, color:Int):FlxSprite
	{
		var btn = new FlxSprite(0, y).makeGraphic(300, 40, color);
		btn.screenCenter(X);
		btn.ID = Std.int(y);
		return btn;
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

		if (FlxG.mouse.justPressed)
		{
			var mp = FlxG.mouse.getScreenPosition();

			if (createRoomBtn.overlapsPoint(mp))
				createRoom();
			else if (joinRoomBtn.overlapsPoint(mp))
				startTypingCode();
			else if (backBtn.overlapsPoint(mp))
			{
				if (client != null) client.disconnect();
				FlxG.switchState(new MainMenuState());
			}
		}

		if (FlxG.keys.justPressed.SPACE && !client.connected)
			connectToServer();
	}

	function connectToServer()
	{
		#if sys
		statusText.text = "Connecting...";
		if (client.connect(SERVER_HOST, SERVER_PORT))
		{
			statusText.text = "Connected! Press SPACE to create or enter a code";
		}
		else
		{
			statusText.text = "Failed to connect! Check if server is running";
		}
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
				if (ft.text == "Type room code, press ENTER to join")
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
