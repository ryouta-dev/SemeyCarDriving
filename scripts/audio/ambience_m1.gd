class_name AmbienceM1
extends Node

## Looping city/river ambience for the bridge slice. The WAVs are generated
## procedurally (tools/generate_ambience.py), so they are CC0 by construction.

const WIND_PATH := "res://sounds/ambience_wind.wav"
const WATER_PATH := "res://sounds/ambience_water.wav"

var _wind: AudioStreamPlayer
var _water: AudioStreamPlayer

func _ready() -> void:
	_wind = _player(WIND_PATH, -20.0)
	_water = _player(WATER_PATH, -24.0)

func _player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	if stream != null:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	if player.stream != null:
		player.play()
	return player
