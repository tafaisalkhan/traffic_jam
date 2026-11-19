class_name AudioManager
extends Node

enum Event { UI_TAP, VEHICLE_SELECT, VEHICLE_EXIT, BLOCKED, HINT, COIN, COMPLETE, FAIL, MUSIC, START, AMBULANCE_SIREN }

const SAMPLE_RATE := 22050
const BgMusic1 := preload("res://assets/audio/bg_music1.mp3")
const BgMusic2 := preload("res://assets/audio/bg_music2.mp3")
const CarHitSound := preload("res://assets/audio/car_hit.wav")
const CoinSound := preload("res://assets/audio/coin_sound.wav")
const LevelCompleteSound := preload("res://assets/audio/level_complete.mp3")
const LevelFailSound := preload("res://assets/audio/level_fail.mp3")
const StarSound := preload("res://assets/audio/star_sound.mp3")

var music_enabled := true
var sound_enabled := true
var music_tracks: Array[AudioStream] = [BgMusic1, BgMusic2]
var music_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0

func _ready() -> void:
	for track in music_tracks:
		var player := AudioStreamPlayer.new()
		player.volume_db = -18.0
		player.stream = track
		player.finished.connect(_on_music_finished.bind(player))
		add_child(player)
		music_players.append(player)
	if not music_players.is_empty():
		music_player = music_players[0]
	for _i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		sfx_players.append(player)
	_apply_audio_settings()

func _on_music_finished(player: AudioStreamPlayer) -> void:
	if not music_enabled or not is_instance_valid(player):
		return
	player.play()

func configure(settings: Dictionary) -> void:
	music_enabled = bool(settings.get("music", true))
	sound_enabled = bool(settings.get("sound", true))
	if is_inside_tree():
		_apply_audio_settings()

func _apply_audio_settings() -> void:
	for player in music_players:
		if not is_instance_valid(player):
			continue
		if music_enabled:
			if not player.playing:
				player.play()
		else:
			player.stop()
	if not sound_enabled:
		for p in sfx_players:
			p.stop()

func play_event(event: Event) -> void:
	if event == Event.MUSIC or not sound_enabled or sfx_players.is_empty():
		return
	var player := sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	match event:
		Event.BLOCKED:
			player.stream = CarHitSound
			player.volume_db = -6.0
		Event.COIN:
			player.stream = CoinSound
			player.volume_db = -6.0
		Event.COMPLETE:
			player.stream = LevelCompleteSound
			player.volume_db = -6.0
		Event.FAIL:
			player.stream = LevelFailSound
			player.volume_db = -6.0
		Event.START:
			player.stream = StarSound
			player.volume_db = -8.0
		Event.AMBULANCE_SIREN:
			player.stream = _make_siren_tone()
			player.volume_db = -10.0
		_:
			var pitch := 520.0
			var length := 0.10
			match event:
				Event.VEHICLE_SELECT: pitch = 570.0
				Event.VEHICLE_EXIT: pitch = 760.0
				Event.HINT: pitch = 660.0
			player.stream = _make_tone(pitch, length)
			player.volume_db = -14.0
	player.play()

func _make_siren_tone() -> AudioStreamWAV:
	var seconds := 0.55
	var frame_count := int(SAMPLE_RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in range(frame_count):
		var progress := float(frame) / float(frame_count)
		var freq := 740.0 if progress < 0.5 else 580.0
		var env := sin(PI * progress)
		var wave := sin(TAU * freq * float(frame) / SAMPLE_RATE)
		var sample := int(wave * env * 9000.0)
		bytes[frame * 2] = sample & 255
		bytes[frame * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream

func _make_tone(frequency: float, seconds: float) -> AudioStreamWAV:
	var frame_count := int(SAMPLE_RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in range(frame_count):
		var progress := float(frame) / float(frame_count)
		var envelope := sin(PI * progress)
		var wave := sin(TAU * frequency * float(frame) / SAMPLE_RATE)
		var sample := int(wave * envelope * 10000.0)
		bytes[frame * 2] = sample & 255
		bytes[frame * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream
