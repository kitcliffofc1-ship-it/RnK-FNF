package funkin.game;

import funkin.backend.FunkinText;
import funkin.backend.scripting.events.note.NoteHitEvent;
import funkin.backend.scripting.events.note.NoteMissEvent;
import funkin.menus.MultiplayerClient;
import funkin.menus.MultiplayerClient.MultiplayerPlayer;

#if sys
class MultiplayerPlayState extends PlayState
{
	public static var mpClient:MultiplayerClient;
	public static var botCount:Int = 0;

	var remoteScoreTexts:Array<FunkinText> = [];
	var remoteHealthBars:Array<FlxSprite> = [];

	var lastSentHealth:Float = -1;
	var lastSentScore:Int = -1;
	var lastSentCombo:Int = -1;
	var syncTimer:Float = 0;

	var botSimTimers:Array<Float> = [];
	var botHealths:Array<Float> = [];
	var botScores:Array<Int> = [];
	var botCombos:Array<Int> = [];

	override function create()
	{
		super.create();

		if (mpClient == null) return;

		mpClient.onNoteHit = onRemoteNoteHit;
		mpClient.onHealthUpdate = onRemoteHealth;
		mpClient.onScoreUpdate = onRemoteScore;
		mpClient.onGameOver = onRemoteGameOver;

		var remoteIdx = 0;

		for (p in mpClient.players)
		{
			if (p.id == mpClient.playerId) continue;
			createRemoteHUD(p.name, remoteIdx++);
		}

		for (i in 0...botCount)
		{
			createRemoteHUD('Bot ${i+1}', remoteIdx++);
			botSimTimers.push(0);
			botHealths.push(1.0);
			botScores.push(0);
			botCombos.push(0);
		}

		attachNetworkHooks();
	}

	function createRemoteHUD(name:String, idx:Int)
	{
		var isRight = (idx % 2 == 0);
		var side = isRight ? FlxG.width - 220 : 20;
		var yOff = 80 + Std.int(idx / 2) * 100;

		var bg = new FlxSprite(side, yOff).makeGraphic(200, 80, 0x88000000);
		bg.scrollFactor.set();
		bg.cameras = [camHUD];
		add(bg);

		var nameTxt = new FunkinText(side + 5, yOff + 5, 190, name, 14);
		nameTxt.scrollFactor.set();
		nameTxt.cameras = [camHUD];
		add(nameTxt);

		var scoreTxt = new FunkinText(side + 5, yOff + 22, 190, "Score: 0", 13);
		scoreTxt.scrollFactor.set();
		scoreTxt.cameras = [camHUD];
		add(scoreTxt);
		remoteScoreTexts.push(scoreTxt);

		var healthBar = new FlxSprite(side + 5, yOff + 45).makeGraphic(190, 12, 0xFF66FF33);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];
		add(healthBar);
		remoteHealthBars.push(healthBar);

		var healthBg = new FlxSprite(side + 5, yOff + 45).makeGraphic(190, 12, 0xFF555555);
		healthBg.scrollFactor.set();
		healthBg.cameras = [camHUD];
		add(healthBg);
	}

	function attachNetworkHooks()
	{
		for (sl in strumLines.members)
		{
			if (sl == null || sl.cpu) continue;

			sl.onHit.add((event) -> {
				sendNoteHit(event);
			});
			sl.onMiss.add((event) -> {
				sendNoteMiss(event);
			});
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mpClient == null) return;
		if (mpClient.connected)
		{
			mpClient.update(elapsed);
			syncTimer += elapsed;
			if (syncTimer >= 0.5)
			{
				syncTimer = 0;
				sendHealth();
				sendScore();
			}
		}

		updateBots(elapsed);
	}

	function updateBots(elapsed:Float)
	{
		for (i in 0...botCount)
		{
			botSimTimers[i] += elapsed;
			if (botSimTimers[i] >= 0.3)
			{
				botSimTimers[i] = 0;
				if (Math.random() < 0.85)
				{
					botCombos[i]++;
					botScores[i] += 350;
				}
				else
				{
					botCombos[i] = 0;
				}
				botHealths[i] += (Math.random() - 0.4) * 0.02;

				var idx = (mpClient != null ? mpClient.players.length - 1 : 0) + i;
				if (idx < remoteScoreTexts.length)
				{
					remoteScoreTexts[idx].text = 'Score: ${botScores[i]}  Combo: ${botCombos[i]}';
					remoteHealthBars[idx].scale.x = Math.max(0, botHealths[i] / 2);
				}
			}
		}
	}

	function sendNoteHit(event:NoteHitEvent)
	{
		if (mpClient == null) return;
		mpClient.send("game_note_hit", {
			noteData: {direction: event.direction},
			rating: event.rating
		});
	}

	function sendNoteMiss(event:NoteMissEvent)
	{
		if (mpClient == null) return;
		mpClient.send("game_note_hit", {
			noteData: {direction: 0},
			rating: "miss"
		});
	}

	function sendHealth()
	{
		if (mpClient == null || health == lastSentHealth) return;
		lastSentHealth = health;
		mpClient.send("game_health", {health: health});
	}

	function sendScore()
	{
		if (mpClient == null) return;
		if (songScore == lastSentScore && combo == lastSentCombo) return;
		lastSentScore = songScore;
		lastSentCombo = combo;
		mpClient.send("game_score", {score: songScore, combo: combo});
	}

	function onRemoteNoteHit(data:Dynamic) {}

	function onRemoteHealth(data:Dynamic)
	{
		var pid:String = data.playerId;
		var hp:Float = data.health;
		var idx = 0;
		for (p in mpClient.players)
		{
			if (p.id == pid)
			{
				if (idx < remoteHealthBars.length)
				{
					remoteHealthBars[idx].scale.x = Math.max(0, hp / 2);
				}
				return;
			}
			if (p.id != mpClient.playerId) idx++;
		}
	}

	function onRemoteScore(data:Dynamic)
	{
		var pid:String = data.playerId;
		var score:Int = data.score;
		var combo:Int = data.combo;
		var idx = 0;
		for (p in mpClient.players)
		{
			if (p.id == pid)
			{
				if (idx < remoteScoreTexts.length)
				{
					remoteScoreTexts[idx].text = 'Score: $score  Combo: $combo';
				}
				return;
			}
			if (p.id != mpClient.playerId) idx++;
		}
	}

	function onRemoteGameOver() {}
}
#end
