class_name ProfileManager
extends RefCounted

## ProfileManager manages player vehicle customization and persistence.
## Stores settings in user://profile.json across sessions.

const SAVE_PATH := "user://profile.json"

static func get_default_profile() -> Dictionary:
	return {
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
			"button_scale": 1.0,         # 0.8 to 1.5
			"steer_mode": "arrows",      # "arrows" or "wheel"
			"steer_pos_x": 40.0,
			"steer_pos_y": -40.0,
			"pedals_pos_x": -40.0,
			"pedals_pos_y": -40.0
		},
		"environment": {
			"time_of_day": "day",        # "day", "sunset", "night"
			"weather": "clear"           # "clear", "rain"
		}
	}

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		var def = get_default_profile()
		save_profile(def)
		return def

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return get_default_profile()

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		push_warning("[ProfileManager] Invalid profile.json, restoring default.")
		return get_default_profile()

	var data: Dictionary = json.data
	# Merge missing keys from default in case of version changes
	var def := get_default_profile()
	for cat in def.keys():
		if not data.has(cat) or not (data[cat] is Dictionary):
			data[cat] = def[cat]
		else:
			for key in def[cat].keys():
				if not data[cat].has(key):
					data[cat][key] = def[cat][key]

	return data

static func save_profile(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[ProfileManager] Failed to write profile to: " + SAVE_PATH)
		return false

	var json_str := JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()
	return true

static func reset_to_default() -> Dictionary:
	var def := get_default_profile()
	save_profile(def)
	return def
