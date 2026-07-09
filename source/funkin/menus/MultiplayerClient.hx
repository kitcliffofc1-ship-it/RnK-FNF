package funkin.menus;

import haxe.Json;

#if sys
import sys.net.Host;
import sys.net.Socket as SysSocket;
import funkin.backend.system.net.Socket;

class MultiplayerClient
{
	public var connected:Bool = false;
	public var playerId:String;
	public var roomId:String;
	public var roomName:String;
	public var hostId:String;
	public var players:Array<MultiplayerPlayer> = [];
	public var roomState:String = "";

	var socket:Socket;
	var messageBuffer:Array<Dynamic> = [];
	var pendingMessages:Array<Dynamic> = [];

	public function new() {}

	public function connect(hostStr:String, port:Int):Bool
	{
		try
		{
			socket = new Socket();
			socket.connect(new Host(hostStr), port);
			connected = true;
			return true;
		}
		catch (e:Dynamic)
		{
			Logs.error("Failed to connect: " + Std.string(e));
			return false;
		}
	}

	public function disconnect()
	{
		if (socket != null)
		{
			socket.destroy();
			socket = null;
		}
		connected = false;
		playerId = null;
		roomId = null;
		players = [];
	}

	public function send(type:String, ?data:Dynamic)
	{
		if (data == null) data = {};
		data.type = type;
		pendingMessages.push(data);
	}

	public function update(elapsed:Float)
	{
		if (socket == null) return;
		flushWrites();
		readMessages();
	}

	function flushWrites()
	{
		for (msg in pendingMessages)
		{
			var json = Json.stringify(msg) + "\n";
			try
			{
				socket.socket.output.writeString(json);
			}
			catch (e:Dynamic)
			{
				Logs.error("Socket write error: " + Std.string(e));
				connected = false;
			}
		}
		pendingMessages = [];
	}

	function readMessages()
	{
		if (socket == null) return;
		try
		{
			var data = socket.read();
			while (data != null)
			{
				var msg:Dynamic = Json.parse(data);
				handleMessage(msg);
				data = socket.read();
			}
		}
		catch (e:Dynamic)
		{
			if (connected)
			{
				Logs.error("Socket read error: " + Std.string(e));
				connected = false;
			}
		}
	}

	function handleMessage(msg:Dynamic)
	{
		var type:String = msg.type;
		switch (type)
		{
			case "room_created":
				playerId = msg.playerId;
				roomId = msg.roomId;
				roomName = msg.roomName;
				hostId = playerId;
				onRoomCreated();
			case "room_joined":
				playerId = msg.playerId;
				roomId = msg.roomId;
				roomName = msg.roomName;
				hostId = msg.hostId;
				players = parsePlayers(msg.players);
				onRoomJoined();
			case "player_joined":
				players = parsePlayers(msg.players);
				onPlayersUpdated();
			case "player_left":
				players = parsePlayers(msg.players);
				if (players.length == 0)
					onRoomClosed();
				else
					onPlayersUpdated();
			case "player_ready":
				players = parsePlayers(msg.players);
				onPlayersUpdated();
			case "player_updated":
				players = parsePlayers(msg.players);
				onPlayersUpdated();
			case "room_list":
				onRoomList(msg.rooms);
			case "game_starting":
				onGameStarting(msg.countdown);
			case "game_start":
				onGameStart(msg.startTime);
			case "game_note_hit":
				onNoteHit(msg);
			case "game_health":
				onHealthUpdate(msg);
			case "game_score":
				onScoreUpdate(msg);
			case "game_over":
				players = parsePlayers(msg.players);
				onGameOver();
			case "error":
				onError(msg.message);
		}
	}

	function parsePlayers(p:Array<Dynamic>):Array<MultiplayerPlayer>
	{
		var result:Array<MultiplayerPlayer> = [];
		if (p == null) return result;
		for (pl in p)
		{
			result.push({
				id: pl.id,
				name: pl.name,
				ready: pl.ready,
				isHost: pl.id == hostId
			});
		}
		return result;
	}

	// callbacks
	public dynamic function onRoomCreated() {}
	public dynamic function onRoomJoined() {}
	public dynamic function onPlayersUpdated() {}
	public dynamic function onRoomList(rooms:Array<Dynamic>) {}
	public dynamic function onRoomClosed() {}
	public dynamic function onGameStarting(countdown:Int) {}
	public dynamic function onGameStart(startTime:Float) {}
	public dynamic function onNoteHit(data:Dynamic) {}
	public dynamic function onHealthUpdate(data:Dynamic) {}
	public dynamic function onScoreUpdate(data:Dynamic) {}
	public dynamic function onGameOver() {}
	public dynamic function onError(msg:String) {}
}

typedef MultiplayerPlayer =
{
	var id:String;
	var name:String;
	var ready:Bool;
	var isHost:Bool;
}

#end
