extends Control

@export var select_sound = AudioStream
@export var go_to_game_sound = AudioStream
@export var back_sound = AudioStream

@export var overlay_pop_duration: float
@export var fade_duration: float = 0.15

# Input binding overlay scenes
@onready var controller_map_scene: CanvasLayer = $ControlsMenu/ControllerMapScene
@onready var keyboard_map_scene: CanvasLayer = $ControlsMenu/KeyboardMapScene

@onready var main_menu: VBoxContainer = $MainMenu
@onready var settings_menu: VBoxContainer = $SettingsMenu
@onready var quit_game_menu: VBoxContainer = $QuitGameMenu
@onready var language_menu: VBoxContainer = $LanguageMenu
@onready var controls_menu: VBoxContainer = $ControlsMenu
@onready var audio_menu: VBoxContainer = $AudioMenu
@onready var gameplay_menu: VBoxContainer = $GameplayMenu
@onready var save_slot_menu: VBoxContainer = $SaveSlotMenu
@onready var pause_menu: VBoxContainer = $PauseMenu
@onready var confirm_delete_menu: VBoxContainer = $ConfirmDeleteMenu
@onready var confirm_quit_menu: VBoxContainer = $ConfirmQuitMenu

var pending_delete_slot: String = ""


var current_menu: VBoxContainer = null
var menu_stack: Array[VBoxContainer] = []
var using_mouse: bool = true
var last_mouse_position: Vector2 = Vector2.ZERO
var last_hovered_button: Button = null

func _ready() -> void:

	# process_mode = PROCESS_MODE_ALWAYS
	audio_menu.volume_changed.connect(_on_volume_changed)

	# Wire up child signals
	main_menu.start_game_requested.connect(func(): show_menu(save_slot_menu))
	main_menu.settings_requested.connect(func(): show_menu(settings_menu))
	main_menu.quit_game_requested.connect(func():show_menu(quit_game_menu))
	pause_menu.settings_requested.connect(func(): show_menu(settings_menu))
	settings_menu.language_requested.connect(func(): show_menu(language_menu))
	settings_menu.controls_requested.connect(func(): show_menu(controls_menu))
	settings_menu.audio_requested.connect(func(): show_menu(audio_menu))
	settings_menu.gameplay_requested.connect(func(): show_menu(gameplay_menu))
	
	# Wire up controls menu buttons for controller and keyboard map overlays
	controls_menu.input_map_requested.connect(_show_input_map_overlay.bind(true))
	keyboard_map_scene.back_requested.connect(_show_input_map_overlay.bind("Keyboard", false))
	controller_map_scene.back_requested.connect(_show_input_map_overlay.bind("Controller", false))
	
	gameplay_menu.screenshake_toggle_requested.connect(_on_screenshake_toggled)
	gameplay_menu.vibrate_toggle_requested.connect(_on_vibrate_toggled)
	gameplay_menu.battery_saver_toggle_requested.connect(_on_battery_saver_toggled)

	pause_menu.quit_requested.connect(func(): show_menu(confirm_quit_menu))
	controls_menu.back_requested.connect(_go_back)
	settings_menu.back_requested.connect(_go_back)
	audio_menu.back_requested.connect(_go_back)
	language_menu.back_requested.connect(_go_back)
	gameplay_menu.back_requested.connect(_go_back)
	save_slot_menu.back_requested.connect(_go_back)
	save_slot_menu.slot_requested.connect(_on_save_slot_selected)
	save_slot_menu.delete_requested.connect(_on_delete_requested)
	confirm_delete_menu.confirm.connect(_on_delete_confirmed)
	confirm_delete_menu.cancel.connect(_go_back)
	confirm_quit_menu.confirm.connect(_quit_to_tile)
	confirm_quit_menu.cancel.connect(_go_back)
	quit_game_menu.confirm.connect(_quit_game)
	quit_game_menu.cancel.connect(_go_back)
	
	# Set menus to invisible at startup
	for child in get_children():
		child.visible = false
	
	# Track the hovered button with the hovered signal
	for child in find_children("*", "Button", true, false):
		child.mouse_entered.connect(func(): 
			if using_mouse:
				last_hovered_button = child
		)

func initialize_menu(menu_name: String = "MainMenu") -> void:
	
	menu_stack.clear()
	
	current_menu = get_node_or_null(menu_name)	
	current_menu.modulate.a = 0.0
	current_menu.visible = true
	
	var fade_in = create_tween()
	fade_in.tween_property(current_menu, "modulate:a", 1.0, fade_duration)
		
func _show_input_map_overlay(input_map_type: String, show: bool) -> void:
	if InputManager.input_lock:
		return

	InputManager.input_lock = true
	
	# Set the type of overlay based on the type parameter passed in
	var input_map_scene = keyboard_map_scene.control if input_map_type == "Keyboard" else controller_map_scene.control

	if show:
		AudioManager.play_sfx(select_sound)
		_focus_first_button(input_map_scene)
		input_map_scene.visible = true
		input_map_scene.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_property(input_map_scene, "modulate:a", 1.0, overlay_pop_duration)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	else:
		AudioManager.play_sfx(back_sound)
		var tween = create_tween()
		tween.tween_property(input_map_scene, "modulate:a", 0.0, overlay_pop_duration)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished

		_focus_first_button(current_menu)
		input_map_scene.visible = false
		input_map_scene.modulate.a = 1.0

	InputManager.input_lock = false

func show_menu(target_menu: VBoxContainer, add_to_stack: bool = true) -> void:
	
	#VibrateManager.run(200)
	
	if InputManager.input_lock:
		return

	InputManager.input_lock = true
	
	# Fade out current active menu panel
	if current_menu and current_menu.visible:
		if add_to_stack:
			AudioManager.play_sfx(select_sound)
			menu_stack.append(current_menu)
		
		var fade_out = create_tween()
		fade_out.tween_property(current_menu, "modulate:a", 0.0, fade_duration)
		await fade_out.finished
		current_menu.visible = false
		
	# Setup and fade in target menu panel
	current_menu = target_menu
	_focus_first_button(current_menu)
	current_menu.modulate.a = 0.0
	current_menu.visible = true
	
	var fade_in = create_tween()
	fade_in.tween_property(current_menu, "modulate:a", 1.0, fade_duration)
	await fade_in.finished
	
	InputManager.input_lock = false

func _on_volume_changed(bus_name:String, value:float) -> void:
	var key = bus_name + " Volume"
	SaveManager.update_setting(key, value)
	
	# Update the AudioServer, matched string names exactly
	var bus_idx = AudioServer.get_bus_index(bus_name)
	
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	else:
		push_warning("Audio Bus not found: " + bus_name)
		
func _on_battery_saver_toggled(is_on: bool) -> void:
	AudioManager.play_sfx(select_sound)
	VibrateManager.run(200)
	SaveManager.update_setting("Battery Saver", is_on)
	Engine.max_fps = 30 if is_on else 60

func _on_vibrate_toggled(is_on: bool) -> void:
	AudioManager.play_sfx(select_sound)
	VibrateManager.run(200)
	SaveManager.update_setting("Vibration", is_on)

func _on_screenshake_toggled(is_on: bool) -> void:
	AudioManager.play_sfx(select_sound)
	VibrateManager.run(200)
	SaveManager.update_setting("Screenshake", is_on)

func _on_delete_requested(slot_id: String) -> void:
	pending_delete_slot = slot_id
	show_menu(confirm_delete_menu)

func _on_delete_confirmed() -> void:
	SaveManager.delete_slot(pending_delete_slot)
	save_slot_menu.update_slot_labels()
	_go_back()

func _on_save_slot_selected(slot_id: String) -> void:
	
	AudioManager.play_sfx(go_to_game_sound)
	VibrateManager.run(200)
	
	SaveManager.current_slot = slot_id
	
	var save_exists: bool = SaveManager.load_from_disk(slot_id)
	SaveManager.game_timer_active = true
	
	if not save_exists:
		SaveManager.SAVE_DATA[slot_id] = {
			#"enemies_dead": [],
			#"room_id": "a_01",
			#"health": 1,
			#"max_health": 4,
			#"energy": 27,
			#"max_energy":27,
			#"coins": 0,
			#"abilities": {}
		}
		
		SaveManager.save_to_disk()
		
	StateManager.change_state(StateManager.GameState.WORLD, 0.5, 2.0, "fade", "fade")
	AudioManager.stop_music(2.0)

func _on_slot_deleted(slot_id: String) -> void:
	# Permanently wipe data from RAM and drop the JSON file from disk
	SaveManager.delete_slot(slot_id)
	
	# Run a quick fade blink to visually refresh the menu state instantly
	InputManager.input_lock = true
	var refresh_tween = create_tween()
	refresh_tween.tween_property(save_slot_menu, "modulate:a", 0.0, fade_duration)
	refresh_tween.tween_property(save_slot_menu, "modulate:a", 1.0, fade_duration)
	await refresh_tween.finished
	InputManager.input_lock = false
	
func _go_back() -> void:
	
	AudioManager.play_sfx(back_sound)
	VibrateManager.run(200)
	
	# If there is nothing left in our history stack, we can't go back further
	if menu_stack.is_empty():
		return
		
	# Bool determines if required to add_to_stack,
	# only adding to stack if moving forward in the show_menu function
	show_menu(menu_stack.pop_back(), false)

func _quit_to_tile() -> void:
	get_tree().paused = false
	SaveManager.close_session()
	StateManager.change_state(StateManager.GameState.TITLE, 0.5, 2.0, "fade", "fade")
	AudioManager.stop_music(2.0)
	AudioManager.play_sfx(go_to_game_sound)

func _quit_game() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	# Detect mouse movement to switch to mouse mode
	if event is InputEventMouseMotion:
		if event.relative.length() > 1:
			if not using_mouse:
				using_mouse = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				
				# Enable the hover button styles for mouse mode
				_set_buttons_hover_style(true)
				
				var focused = get_viewport().gui_get_focus_owner()
				if focused:
					focused.release_focus()

	# Detect keyboard/gamepad navigation to switch mode
	elif (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or 
		  event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or 
		  event.is_action_pressed("ui_accept")):
		
		if using_mouse:
			using_mouse = false
			last_mouse_position = get_viewport().get_mouse_position()
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			
			# Disable the hover button styles for keyboard/gamepad mode
			_set_buttons_hover_style(false)
		
		if get_viewport().gui_get_focus_owner() == null:
			if last_hovered_button:
				last_hovered_button.grab_focus()
				
			else:
				_focus_first_button(current_menu)
				
			get_viewport().set_input_as_handled()

# Helper function to dynamically toggle button hover states
func _set_buttons_hover_style(enabled: bool) -> void:
	for child in find_children("*", "Button", true, false):

		if enabled:
			child.remove_theme_color_override("font_hover_color")
			child.remove_theme_color_override("font_hover_pressed_color")
		else:
			var normal_font_color = child.get_theme_color("font_color")
			child.add_theme_color_override("font_hover_color", normal_font_color)
			child.add_theme_color_override("font_hover_pressed_color", normal_font_color)

func _focus_first_button(node: Node) -> void:
	if using_mouse:
		return
		
	for child in node.find_children("*", "Button", true, false):
		if child.visible:
			child.grab_focus()
			break


		
