extends CanvasLayer

signal back_requested

@onready var control: Control = $Control
@onready var column_1: VBoxContainer = $Control/KeyboardMenu/HBoxContainer/Column1
@onready var column_2: VBoxContainer = $Control/KeyboardMenu/HBoxContainer/Column2
@onready var back_button: Button = $Control/KeyboardMenu/BackButton
@onready var tooltip_label: Label = $Control/TooltipLabel

# Track remapping state
var remapping_button: Button = null
var remapping_action: String = ""

func _ready() -> void:

	control.visible = false
	tooltip_label.visible = false

	_setup_focus_neighbors()
	_update_all_button_labels()

	back_button.pressed.connect(func(): back_requested.emit())
	
	InputManager.controller_connection_changed.connect(func(_connected):
		_update_all_button_labels()
		back_requested.emit())
	
func _update_button_text_for_action(btn: Button) -> void:
	var action_name = btn.name.replace("Button", "")
	if InputMap.has_action(action_name):
		# Find the first joypad event in the action (ignoring keyboard/mouse bindings)
		var joy_event: InputEvent = null
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				joy_event = ev
				break
				
		if joy_event:
			btn.text = InputManager.get_joypad_event_label(joy_event)
		else:
			btn.text = "Unassigned"

func _setup_focus_neighbors() -> void:
	var col1_buttons = _get_buttons_in_column(column_1)
	var col2_buttons = _get_buttons_in_column(column_2)
	
	var max_rows = max(col1_buttons.size(), col2_buttons.size())
	
	# 1. Strict Vertical & Horizontal wiring for Column 1
	for i in range(col1_buttons.size()):
		var btn = col1_buttons[i]
		
		# Vertical Top
		if i > 0:
			btn.focus_neighbor_top = col1_buttons[i - 1].get_path()
		else:
			btn.focus_neighbor_top = back_button.get_path()
			
		# Vertical Bottom
		if i < col1_buttons.size() - 1:
			btn.focus_neighbor_bottom = col1_buttons[i + 1].get_path()
		else:
			btn.focus_neighbor_bottom = back_button.get_path()
			
		# TRAP LEFT: Prevent pressing left from escaping Column 1
		btn.focus_neighbor_left = btn.get_path()

	# 2. Strict Vertical & Horizontal wiring for Column 2
	for i in range(col2_buttons.size()):
		var btn = col2_buttons[i]
		
		# Vertical Top
		if i > 0:
			btn.focus_neighbor_top = col2_buttons[i - 1].get_path()
		else:
			btn.focus_neighbor_top = back_button.get_path()
			
		# Vertical Bottom
		if i < col2_buttons.size() - 1:
			btn.focus_neighbor_bottom = col2_buttons[i + 1].get_path()
		else:
			btn.focus_neighbor_bottom = back_button.get_path()

	# 3. Strict Horizontal bridging between columns at the same index
	for i in range(max_rows):
		var btn1 = col1_buttons[i] if i < col1_buttons.size() else null
		var btn2 = col2_buttons[i] if i < col2_buttons.size() else null
		
		if btn1 and btn2:
			btn1.focus_neighbor_right = btn2.get_path()
			btn2.focus_neighbor_left = btn1.get_path()
		elif btn2:
			btn2.focus_neighbor_left = btn2.get_path()

	# 4. Strict wiring for the Back button
	if col1_buttons.size() > 0 and col2_buttons.size() > 0:
		back_button.focus_neighbor_top = col1_buttons.back().get_path()     # Up goes to last button of Col 1
		back_button.focus_neighbor_bottom = col1_buttons[0].get_path()      # Down wraps to first button of Col 1
		
		# Back button Left/Right stays entirely on the bottom row elements
		back_button.focus_neighbor_left = col1_buttons.back().get_path()    # Left from Back goes to Col 1 bottom
		back_button.focus_neighbor_right = col2_buttons.back().get_path()   # Right from Back goes to Col 2 bottom

func _get_buttons_in_column(col: VBoxContainer) -> Array:
	var buttons = []
	for row in col.get_children():		
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					buttons.append(child)
					if not child.pressed.is_connected(_on_button_pressed):
						child.pressed.connect(_on_button_pressed.bind(child))
	return buttons

func _update_all_button_labels() -> void:
	var col1_buttons = _get_buttons_in_column(column_1)
	var col2_buttons = _get_buttons_in_column(column_2)
	for btn in col1_buttons + col2_buttons:
		_update_button_text_for_action(btn)


func _on_button_pressed(btn: Button) -> void:
	if remapping_button != null:
		return
		
	var action_name = btn.name.replace("Button", "")
	
	if InputMap.has_action(action_name):
		remapping_button = btn
		remapping_action = action_name
		btn.text = "???"
		tooltip_label.visible = true

func _input(event: InputEvent) -> void:
	if remapping_button == null:
		return
	
	# Block keyboard keys and mouse clicks/motion in the controller menu
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.is_pressed():
			return
		
	# Listen for valid Controller / Gamepad inputs (Buttons or Axis/Stick tilts >= 0.5)
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_pressed() or (event is InputEventJoypadMotion and abs(event.axis_value) >= 0.5):
			get_viewport().set_input_as_handled()
			
			InputMap.action_erase_events(remapping_action)
			InputMap.action_add_event(remapping_action, event)
			
			_update_button_text_for_action(remapping_button)
			remapping_button = null
			remapping_action = ""
			tooltip_label.visible = false
