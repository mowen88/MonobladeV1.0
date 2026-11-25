extends Node

# --- SETTINGS CONFIGURATION ---

# Device path to save data to
const SETTINGS_PATH = "user://settings.json"
# Total room count var not const due to .size() being runtime function not compile time
#var TOTAL_ROOMS: float = 5#MapData.ROOM_REGISTRY.size()

var TOTAL_ROOMS: int:
	get:
		var room_count = 0
		for room_list in MapData.ROOM_REGISTRY.values():
			room_count += room_list.size()
		return room_count

var SETTINGS_DATA: Dictionary = {
	"Master Volume": 1.0,
	"Music Volume": 1.0,
	"SFX Volume": 1.0,
	"Battery Saver": true,
	"Screenshake": true,
	"Vibration": true,
	"Language": "en",
	"Keybindings": {}
}

var default_keybindings: Dictionary = {}

## Debug override start room for testing
var debug_override_room: PackedScene = null# preload("res://states/world_state/rooms/a_01.tscn")

# --- SAVE SLOT CONFIGURATION ---
var current_slot: String = "1"
var game_timer_active: bool = false

# Track the sessions visited rooms (only commited to disk when saving at station)
var session_visited_rooms: Array = []

# Runtime game memory
var SAVE_DATA: Dictionary = {
	"1": {},
	"2": {},
	"3": {}
}

func _ready() -> void:
	
	_capture_default_input_mappings()
	_load_settings()
	_load_input_mappings()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
func _process(delta:float) -> void:
	if game_timer_active and SAVE_DATA.has(current_slot):
		if not SAVE_DATA[current_slot].has("game_time"):
			SAVE_DATA[current_slot]["game_time"] = 0.0
		
		SAVE_DATA[current_slot]["game_time"] += delta

func _capture_default_input_mappings() -> void:
	default_keybindings.clear()
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		var cloned_events: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			cloned_events.append(event.duplicate())
		default_keybindings[action] = cloned_events

func reset_input_mappings_to_default() -> void:
	for action in default_keybindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event in default_keybindings[action]:
			InputMap.action_add_event(action, event.duplicate())
	save_input_mappings()
	
func save_input_mappings() -> void:
	var keybindings = {}

	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue

		var events_array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				events_array.append({
					"type": "key",
					"keycode": event.keycode,
					"physical_keycode": event.physical_keycode
				})
			elif event is InputEventMouseButton:
				events_array.append({ "type": "mouse_button", "button_index": event.button_index })
			elif event is InputEventJoypadButton:
				events_array.append({ "type": "joy_button", "button_index": event.button_index })
			elif event is InputEventJoypadMotion:
				events_array.append({ "type": "joy_motion", "axis": event.axis, "axis_value": event.axis_value })

		keybindings[action] = events_array

	SETTINGS_DATA["Keybindings"] = keybindings
	_save_settings()
	print_rich("[color=green]SAVE SYSTEM: Input mappings saved to disk.[/color]")

func _load_input_mappings() -> void:
	if not SETTINGS_DATA.has("Keybindings") or SETTINGS_DATA["Keybindings"].is_empty():
		return

	var keybindings: Dictionary = SETTINGS_DATA["Keybindings"]
	for action in keybindings:
		if not InputMap.has_action(action):
			continue

		InputMap.action_erase_events(action)

		for event_data in keybindings[action]:
			var new_event: InputEvent = null
			match event_data.get("type"):
				"key":
					var kc: int = int(event_data.get("keycode", 0))
					var pkc: int = int(event_data.get("physical_keycode", 0))
					if kc != 0 or pkc != 0:
						var key_ev := InputEventKey.new()
						key_ev.keycode = kc
						key_ev.physical_keycode = pkc
						new_event = key_ev
				"mouse_button":
					var mouse_ev := InputEventMouseButton.new()
					mouse_ev.button_index = event_data.get("button_index", MOUSE_BUTTON_NONE)
					if mouse_ev.button_index != MOUSE_BUTTON_NONE:
						new_event = mouse_ev
				"joy_button":
					var joy_btn_ev := InputEventJoypadButton.new()
					joy_btn_ev.button_index = event_data.get("button_index", 0)
					new_event = joy_btn_ev
				"joy_motion":
					var joy_motion_ev := InputEventJoypadMotion.new()
					joy_motion_ev.axis = event_data.get("axis", 0)
					joy_motion_ev.axis_value = event_data.get("axis_value", 1.0)
					new_event = joy_motion_ev

			if new_event:
				InputMap.action_add_event(action, new_event)

	print_rich("[color=green]SAVE SYSTEM: Input mappings successfully loaded & applied.[/color]")
	
## Add unique ability to save slot
func add_ability(ability_name: String) -> void:

	if not SAVE_DATA[current_slot].has("abilities"):
		SAVE_DATA[current_slot]["abilities"] = {}
		
	var abilities: Dictionary = SAVE_DATA[current_slot]["abilities"]
	
	if not abilities.has(ability_name):
		abilities[ability_name] = true
		#print_rich("[color=cyan]SAVE SYSTEM: Unlocked ability '%s' for Slot %s[/color]" % [ability_name, current_slot])
		save_to_disk()

## Add item to save slot
func add_item(item_name: String) -> void:

	if not SAVE_DATA[current_slot].has("items"):
		SAVE_DATA[current_slot]["items"] = {}
		
	var items: Dictionary = SAVE_DATA[current_slot]["items"]
	
	# Add to current dictionary, default to 0 if not exists so adds 1
	items[item_name] = items.get(item_name, 0) + 1
		
	#print_rich("[color=cyan]SAVE SYSTEM: Collected item '%s' for Slot %s[/color]" % [item_name, current_slot])
	save_to_disk()
		
## Helper that calculates and saves the integer percentage directly into the slot dict
func _update_game_completion_percentage(slot_id: String) -> void:
	if not SAVE_DATA.has(slot_id) or not SAVE_DATA[slot_id].has("visited_rooms"):
		SAVE_DATA[slot_id]["percent_complete"] = 0
		return
		
	var visited_room_count: float = float(SAVE_DATA[slot_id]["visited_rooms"].size())
	var percentage = (visited_room_count / TOTAL_ROOMS) * 100.0
	
	# Keep it right here inside primary dictionary state
	SAVE_DATA[slot_id]["percent_complete"] = int(clamp(percentage, 0.0, 100.0))

## Formats both total play time and map completion percentage into a clean, combined string layout
func get_game_time_as_string(slot_id: String = current_slot) -> String:
	if not SAVE_DATA.has(slot_id):
		return "00h00m00s | 0%"
		
	var total_seconds: int = int(SAVE_DATA[slot_id].get("game_time", 0.0))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	
	var time_string = "%02dh%02dm%02ds" % [hours, minutes, seconds]
	
	return time_string
	
func get_completion_percent_as_string(slot_id: String = current_slot) -> String:
	var map_percent: int = SAVE_DATA[slot_id].get("percent_complete", 0)
	return str(map_percent) + "%"
	
# --- SETTINGS MANAGEMENT ---

func update_setting(key: String, value) -> void:
	if SETTINGS_DATA.has(key):
		SETTINGS_DATA[key] = value
		_save_settings()
	else:
		push_warning("Setting key not found: " + key)

func _save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(SETTINGS_DATA, "\t")
		file.store_string(json_string)
		file.close()
		print_rich("[color=cyan]SAVE SYSTEM: Settings saved to disk.[/color]")

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
		
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parsed_data = JSON.parse_string(json_string)
		if parsed_data is Dictionary:
			for key in parsed_data:
				if SETTINGS_DATA.has(key):
					SETTINGS_DATA[key] = parsed_data[key]
			print_rich("[color=cyan]SAVE SYSTEM: Settings loaded from disk.[/color]")
		file.close()

# --- SAVE SLOT MANAGEMENT ---

func _get_save_path(slot_id: String) -> String:
	return "user://save_slot_%s.json" % slot_id

## Universal tracker for any persistent entity (secret walls, bosses, special items)
func save_persistent_object(object_id: String) -> void:
	if not SAVE_DATA.has(current_slot):
		return
		
	if not SAVE_DATA[current_slot].has("persistent_objects"):
		SAVE_DATA[current_slot]["persistent_objects"] = []
		
	var persistent_list: Array = SAVE_DATA[current_slot]["persistent_objects"]
	if not persistent_list.has(object_id):
		persistent_list.append(object_id)
		SAVE_DATA[current_slot]["persistent_objects"] = persistent_list
		print_rich("[color=yellow]SAVE SYSTEM: Registered persistent object %s[/color]" % object_id)
		save_to_disk()
	else:
		print_rich("[color=red]SAVE SYSTEM: Persistent object already registered %s[/color]" % object_id)

func save_at_station(room_name: String, player: CharacterBody2D) -> void:
	if not SAVE_DATA.has(current_slot):
		SAVE_DATA[current_slot] = {}
	
	# Save the current room ID so the game knows where to reload you!
	SAVE_DATA[current_slot]["room_id"] = room_name.to_lower()
	
	var current_time = SAVE_DATA[current_slot].get("game_time", 0.0)
	var permanent_visited = SAVE_DATA[current_slot].get("visited_rooms", [room_name])
	
	# Merge newly discovered session rooms into the permanent list
	for room in player.session_visited_rooms:
		if not permanent_visited.has(room):
			permanent_visited.append(room)
	
	# Clear the player's session rooms as they're now commited to save
	player.session_visited_rooms.clear()
			
	var existing_banked_coins = SAVE_DATA[current_slot].get("coins", player.banked_coins)
	var new_banked_total = existing_banked_coins + player.current_coins
	
	player.banked_coins = new_banked_total
	player.current_coins = 0
	
	# 3. Commit everything to the slot and write to disk
	SAVE_DATA[current_slot]["room_id"] = room_name
	SAVE_DATA[current_slot]["spawn_id"] = 0
	SAVE_DATA[current_slot]["health"] = player.health_component.max_health
	SAVE_DATA[current_slot]["max_health"] = player.health_component.max_health
	SAVE_DATA[current_slot]["energy"] = player.energy_component.current_energy
	SAVE_DATA[current_slot]["max_energy"] = player.energy_component.max_energy
	SAVE_DATA[current_slot]["coins"] = new_banked_total
	SAVE_DATA[current_slot]["game_time"] = current_time
	SAVE_DATA[current_slot]["visited_rooms"] = permanent_visited
	
	_update_game_completion_percentage(current_slot)
	save_to_disk()

func save_to_disk() -> void:
	var path = _get_save_path(current_slot)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(SAVE_DATA[current_slot], "\t")
		file.store_string(json_string)
		file.close()
		print_rich("[color=green]SAVE SYSTEM: Successfully wrote Slot %s to disk.[/color]" % current_slot)
	else:
		print_rich("[color=red]SAVE ERROR: Failed to open file path for writing: %s[/color]" % path)

func load_from_disk(slot_id: String) -> bool:
	var path = _get_save_path(slot_id)
	
	if not FileAccess.file_exists(path):
		print_rich("[color=yellow]SAVE SYSTEM: No save file found for Slot %s on disk.[/color]" % slot_id)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var parsed_data = JSON.parse_string(json_string)
		if parsed_data is Dictionary:
			SAVE_DATA[slot_id] = parsed_data
			print_rich("[color=green]SAVE SYSTEM: Successfully loaded Slot %s from disk.[/color]" % slot_id)
			return true
			
	return false

func get_saved_room() -> PackedScene:
	if debug_override_room != null:
		return debug_override_room
		
	var room_name: String = "a_01"
	
	if SAVE_DATA.has(current_slot) and SAVE_DATA[current_slot].has("room_id"):
		room_name = SAVE_DATA[current_slot]["room_id"]
		
	# Ensure the path components are lowercased to match Android's case-sensitive file system
	var clean_name = room_name.to_lower()
	var room_path: String = "res://states/world_state/rooms/%s.tscn" % [clean_name]
	
	if ResourceLoader.exists(room_path):
		var loaded_scene = load(room_path) as PackedScene
		if loaded_scene:
			return loaded_scene
			
	return preload("res://states/world_state/rooms/a_01.tscn")

func delete_slot(slot_id: String) -> void:
	SAVE_DATA[slot_id] = {}
	var path = _get_save_path(slot_id)
	
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			var error = dir.remove(path.get_file())
			if error == OK:
				print_rich("[color=red]SAVE SYSTEM: Erased save file for Slot %s from disk.[/color]" % slot_id)
			else:
				print_rich("[color=yellow]SAVE ERROR: Failed to delete. Error code: %s[/color]" % error)
	else:
		print_rich("[color=yellow]SAVE SYSTEM: No file existed to delete for Slot %s.[/color]" % slot_id)

## Write data if the current world/game session is closed i.e. return to menu
func close_session() -> void:
	if game_timer_active:
		save_to_disk()
		game_timer_active = false

## Mobile OS safe guard. Saves state to disk instantly if app backgrounded/swiped away
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_timer_active:
			save_to_disk()
