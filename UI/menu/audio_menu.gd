extends VBoxContainer

@export var reset_sound: AudioStream

signal back_requested
signal volume_changed(bus_name: String, value: float)

const DEFAULT_VOLUME: float = 1.0

var settings_map: Dictionary = {}

func _ready() -> void:
	# 1. Map your UI nodes to their SaveManager keys
	settings_map = {
		"Master": $MasterRow/MasterSlider,
		"Music": $MusicRow/MusicSlider,
		"SFX": $SFXRow/SFXSlider
	}

	# 2. Set values FIRST
	for bus_name in settings_map:
		var slider: Range = settings_map[bus_name]
		var key = bus_name + " Volume"
		slider.value = SaveManager.SETTINGS_DATA.get(key, DEFAULT_VOLUME)

	# 3. Connect signals SECOND (prevents "snapping" or "reset" loops)
	for bus_name in settings_map:
		var slider: Range = settings_map[bus_name]
		slider.value_changed.connect(_on_slider_changed.bind(bus_name))

	# 4. Handle other buttons
	$BackButton.pressed.connect(func(): back_requested.emit())
	$ResetDefaultsButton.pressed.connect(_on_reset_defaults_requested)

func _on_reset_defaults_requested() -> void:
	AudioManager.play_sfx(reset_sound)
	for bus_name in settings_map:
		var slider: Range = settings_map[bus_name]
		slider.set_value_no_signal(DEFAULT_VOLUME)
		_on_slider_changed(DEFAULT_VOLUME, bus_name)

func _on_slider_changed(value: float, bus_name: String) -> void:
	# Update SaveManager's dictionary and persist if available
	var key := bus_name + " Volume"
	SaveManager.SETTINGS_DATA[key] = value
	if SaveManager.has_method("update_setting"):
		SaveManager.update_setting(key, value)

	# Apply changes to Godot's Audio Server
	_apply_volume_to_server(bus_name, value)

	volume_changed.emit(bus_name, value)

func _apply_volume_to_server(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_error("AudioMenu: Audio bus '" + bus_name + "' was not found in your Godot project!")
		return

	# Convert linear 0.0 - 1.0 slider value to Decibels
	var db_value := linear_to_db(linear_value)
	AudioServer.set_bus_volume_db(bus_index, db_value)

	# Mute the bus completely if the slider is dragged all the way to 0
	AudioServer.set_bus_mute(bus_index, linear_value <= 0.0)
