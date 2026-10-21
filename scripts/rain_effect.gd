class_name RainEffect
extends Node3D

var follow: Node3D
var _particles: CPUParticles3D
var _audio: AudioStreamPlayer

func _ready() -> void:
	_particles = CPUParticles3D.new()
	var quality: String = ProfileManager.load_profile()["settings"]["quality"]
	_particles.amount = 64 if quality == "low" else 160
	_particles.lifetime = 0.7
	_particles.emitting = false
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(12, 1, 12)
	_particles.direction = Vector3.DOWN
	_particles.spread = 5.0
	_particles.initial_velocity_min = 20.0
	_particles.initial_velocity_max = 26.0
	_particles.gravity = Vector3(0, -9.8, 0)
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.30, 0.015)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.58, 0.7, 0.85, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = material
	_particles.mesh = drop
	add_child(_particles)
	_audio = AudioStreamPlayer.new()
	var stream := load("res://sounds/rain_generated.wav") as AudioStreamWAV
	if stream != null:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_audio.stream = stream
	_audio.volume_db = -80.0
	add_child(_audio)

func _process(_delta: float) -> void:
	if is_instance_valid(follow):
		global_position = follow.global_position + Vector3(0, 10, 0)

func set_level(value: float) -> void:
	if _particles == null:
		return
	_particles.emitting = value > 0.12
	if _audio.stream != null:
		_audio.volume_db = linear_to_db(maxf(0.0001, value * 0.22))
		if value > 0.01 and not _audio.playing:
			_audio.play()
		elif value <= 0.01:
			_audio.stop()
