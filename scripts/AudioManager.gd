extends Node
## AudioManager - Singleton for centralized audio playback and volume control

# Audio streams (loaded on init)
var click_stream: AudioStream
var collect_stream: AudioStream

# Audio players
var click_player: AudioStreamPlayer
var collect_player: AudioStreamPlayer

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

const VOLUME_SAVE_PATH: String = "user://audio_settings.json"


func _ready() -> void:
	# Load audio streams
	click_stream = preload("res://assets/audio/click.wav")
	collect_stream = preload("res://assets/audio/collect.wav")

	# Create audio players
	click_player = AudioStreamPlayer.new()
	click_player.stream = click_stream
	click_player.bus = "Master"
	add_child(click_player)

	collect_player = AudioStreamPlayer.new()
	collect_player.stream = collect_stream
	collect_player.bus = "Master"
	add_child(collect_player)

	# Load saved volume settings
	_load_volume_settings()
	_apply_volume()


func play_click() -> void:
	if click_player and not click_player.playing:
		click_player.play()


func play_collect() -> void:
	if collect_player and not collect_player.playing:
		collect_player.play()


func set_master_volume(value: float) -> void:
	master_volume = value
	_save_volume_settings()


func get_master_volume() -> float:
	return master_volume


func _apply_volume() -> void:
	# Convert linear volume (0-1) to decibels
	# -80 dB is effectively silent, 0 dB is full volume
	var db = linear_to_db(master_volume) if master_volume > 0.0 else -80.0

	if click_player:
		click_player.volume_db = db
	if collect_player:
		collect_player.volume_db = db


func _save_volume_settings() -> void:
	var settings = {
		"master_volume": master_volume
	}
	var file = FileAccess.open(VOLUME_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()


func _load_volume_settings() -> void:
	if not FileAccess.file_exists(VOLUME_SAVE_PATH):
		return

	var file = FileAccess.open(VOLUME_SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) == OK and json.data is Dictionary:
		master_volume = float(json.data.get("master_volume", 1.0))
