class_name ProfileManager
extends RefCounted

const SAVE_PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.json.bak"
const TEMP_PATH := "user://profile.json.tmp"
const SCHEMA_VERSION := 2

static func get_default_profile() -> Dictionary:
	return {
		"schema_version": 2,
		"camera": {"mode": 0, "seat_height": 0.0, "seat_forward": 0.0},
		"car": {"selected_car": "simcade_car"},
		"settings": {"quality": "balanced", "dynamic_time": false, "traffic": false, "debug_ui": false, "muted": false},
		"progression": {"credits": 0, "best_sprint": 0.0, "best_drift": 0, "brake_level": 0},
		"handling": {"preset": "sport"},
		"paint": {
			"color": [0.85, 0.12, 0.12, 1.0], # Red default
			"finish": "gloss", # "gloss", "metallic", "matte"
			"tint_alpha": 0.5, # 0.0 (clear) to 0.95 (limo/bunker)
			"rim_color": [0.85, 0.85, 0.88, 1.0], # Silver
			"rim_finish": "metallic"
		},
		"stance": {
			"front_spring_length": 0.15, # 0.08 (lowered) to 0.24 (lifted)
			"rear_spring_length": 0.20,  # 0.10 to 0.28
			"front_camber": 0.0,         # 0.0 to -8.0 degrees
			"rear_camber": 0.0,          # 0.0 to -8.0 degrees
			"front_offset": 0.0,         # -0.02 to 0.08 meters (track width)
			"rear_offset": 0.0,          # -0.02 to 0.08 meters
			"stiffness": 1.0             # 0.6 (comfort) to 2.2 (drift track)
		},
		"engine": {
			"engine_id": "stock_25",     # "stock_25", "v6_35", "jz_turbo", "v8_beast"
			"drivetrain": "rwd",         # "rwd", "awd"
			"final_drive": 3.45          # 2.8 to 4.3
		},
		"hud": {
			"minimap": true,
			"button_scale": 1.0,         # 0.8 to 1.5
			"steer_mode": "arrows",      # "arrows" or "wheel"
			"steer_pos_x": 20.0,
			"steer_pos_y": -20.0,
			"pedals_pos_x": -20.0,
			"pedals_pos_y": -20.0
		},
		"environment": {
			"time_of_day": "day",        # "day", "sunset", "night"
			"weather": "clear"           # "clear", "rain"
		}
	}

static func _read_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	file.close()
	if err != OK or not (parser.data is Dictionary):
		return {}
	return parser.data

static func load_profile() -> Dictionary:
	var raw := _read_profile(SAVE_PATH)
	if raw.is_empty():
		raw = _read_profile(BACKUP_PATH)
		if not raw.is_empty():
			push_warning("Profile restored from backup.")
	return validate_profile(raw)

static func _number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is int or value is float):
		return fallback
	var number := float(value)
	return clampf(number, low, high) if is_finite(number) else fallback

static func validate_profile(raw: Dictionary) -> Dictionary:
	var result := get_default_profile()
	for category in result:
		if not (result[category] is Dictionary):
			continue
		var incoming: Variant = raw.get(category, {})
		if not (incoming is Dictionary):
			continue
		for key in result[category]:
			var value: Variant = incoming.get(key, result[category][key])
			var fallback: Variant = result[category][key]
			if fallback is Array:
				if value is Array and value.size() == 4:
					for i in range(4):
						result[category][key][i] = _number(value[i], fallback[i], 0.0, 1.0)
			elif fallback is bool:
				if value is bool:
					result[category][key] = value
			elif fallback is int or fallback is float:
				result[category][key] = _number(value, fallback, -1000000.0, 1000000.0)
			elif value is String:
				result[category][key] = value
	var ranges := {
		"paint": {"tint_alpha": [0.0, 0.95]},
		"stance": {"front_spring_length": [0.08, 0.28], "rear_spring_length": [0.10, 0.30],
			"front_camber": [-8.0, 0.0], "rear_camber": [-8.0, 0.0],
			"front_offset": [-0.02, 0.08], "rear_offset": [-0.02, 0.08], "stiffness": [0.6, 2.2]},
		"engine": {"final_drive": [2.8, 4.3]},
		"camera": {"mode": [0.0, 2.0], "seat_height": [-0.25, 0.25], "seat_forward": [-0.25, 0.25]},
		"hud": {"button_scale": [0.7, 1.5], "steer_pos_x": [20.0, 700.0],
			"steer_pos_y": [-500.0, -20.0], "pedals_pos_x": [-700.0, -20.0], "pedals_pos_y": [-500.0, -20.0]},
		"progression": {"credits": [0.0, 100000000.0], "best_sprint": [0.0, 86400.0],
			"best_drift": [0.0, 100000000.0], "brake_level": [0.0, 3.0]}
	}
	for category in ranges:
		for key in ranges[category]:
			var limits: Array = ranges[category][key]
			result[category][key] = clampf(float(result[category][key]), limits[0], limits[1])
	var choices := {
		"paint": {"finish": ["gloss", "metallic", "matte"], "rim_finish": ["gloss", "metallic", "matte"]},
		"engine": {"engine_id": ["stock_25", "v6_35", "jz_turbo", "v8_beast"], "drivetrain": ["rwd", "awd"]},
		"hud": {"steer_mode": ["arrows", "wheel"]},
		"environment": {"time_of_day": ["day", "sunset", "night"], "weather": ["clear", "rain"]},
		"settings": {"quality": ["low", "balanced", "high"]},
		"handling": {"preset": ["comfort", "sport", "drift"]},
		"car": {"selected_car": ["simcade_car", "lada_vaz_2110", "priora"]}
	}
	var base := get_default_profile()
	for category in choices:
		for key in choices[category]:
			if result[category][key] not in choices[category][key]:
				result[category][key] = base[category][key]
	result["schema_version"] = SCHEMA_VERSION
	result["camera"]["mode"] = int(result["camera"]["mode"])
	for key in ["credits", "best_drift", "brake_level"]:
		result["progression"][key] = int(result["progression"][key])
	return result

static func save_sections(sections: Dictionary) -> bool:
	var latest := load_profile()
	for category in sections:
		if sections[category] is Dictionary and latest.get(category) is Dictionary:
			latest[category].merge(sections[category], true)
	return save_profile(latest)

static func save_profile(data: Dictionary) -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open temporary profile: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(validate_profile(data), "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	var main_path := ProjectSettings.globalize_path(SAVE_PATH)
	var backup := ProjectSettings.globalize_path(BACKUP_PATH)
	var temp := ProjectSettings.globalize_path(TEMP_PATH)
	var backed_up := false
	if FileAccess.file_exists(SAVE_PATH):
		if not _read_profile(SAVE_PATH).is_empty():
			if FileAccess.file_exists(BACKUP_PATH):
				if DirAccess.remove_absolute(backup) != OK:
					return false
			if DirAccess.rename_absolute(main_path, backup) != OK:
				return false
			backed_up = true
		else:
			if DirAccess.remove_absolute(main_path) != OK:
				return false
	var err := DirAccess.rename_absolute(temp, main_path)
	if err != OK:
		if backed_up:
			DirAccess.rename_absolute(backup, main_path)
		push_error("Cannot commit profile: %s" % err)
		return false
	return true

static func reset_to_default() -> Dictionary:
	# Reset vehicle tuning only; preserve controls, camera, car selection and rewards.
	var data := load_profile()
	var defaults := get_default_profile()
	for section in ["paint", "stance", "engine", "handling"]:
		data[section] = defaults[section].duplicate(true)
	save_profile(data)
	return data
