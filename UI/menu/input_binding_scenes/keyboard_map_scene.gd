extends Control

signal back_requested

@onready var column_1: VBoxContainer = $KeyboardMenu/HBoxContainer/Column1
@onready var column_2: VBoxContainer = $KeyboardMenu/HBoxContainer/Column2
@onready var back_button: Button = $KeyboardMenu/BackButton
@onready var tooltip_label: Label = $TooltipLabel

# Track remapping state
var remapping_button: Button = null
var remapping_action: String = ""

func _ready() -> void:
	tooltip_label.visible = false
	
	_setup_focus_neighbors()
	_update_all_button_labels()

	back_button.pressed.connect(func(): back_requested.emit())

func _setup_focus_neighbors() -> void:
	# Especially for the 2 column input menu
	var col1_buttons = _get_buttons_in_column(column_1)
	var col2_buttons = _get_buttons_in_column(column_2)
	
	var max_rows = max(col1_buttons.size(), col2_buttons.size())
	for i in range(max_rows):
		var btn1 = col1_buttons[i] if i < col1_buttons.size() else null
		var btn2 = col2_buttons[i] if i < col2_buttons.size() else null
		
		if btn1 and btn2:
			btn1.focus_neighbor_right = btn2.get_path()
			btn2.focus_neighbor_left = btn1.get_path()

	if col1_buttons.size() > 0:
		var last_btn1 = col1_buttons.back()
		last_btn1.focus_neighbor_bottom = back_button.get_path()
		back_button.focus_neighbor_top = last_btn1.get_path()
		
	if col2_buttons.size() > 0:
		var last_btn2 = col2_buttons.back()
		last_btn2.focus_neighbor_bottom = back_button.get_path()

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

func _update_button_text_for_action(btn: Button) -> void:
	var action_name = btn.name.replace("Button", "")
	if InputMap.has_action(action_name):
		var events = InputMap.action_get_events(action_name)
		if events.size() > 0:
			var raw_text = events[0].as_text()
			
			# Clean up any variant of physical key formatting Godot uses
			raw_text = raw_text.replace(" (Physical)", "")
			raw_text = raw_text.replace("Physical", "")
			raw_text = raw_text.replace("-", "")
			raw_text = raw_text.replace(":", "")
			raw_text = raw_text.strip_edges()
			
			btn.text = raw_text
		else:
			btn.text = "Unassigned"

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
	
	# Block gamepad buttons and stick/trigger motions in keyboard menu
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_pressed() or (event is InputEventJoypadMotion and abs(event.axis_value) >= 0.5):
			return
		
	if event.is_pressed():
		get_viewport().set_input_as_handled()
		
		InputMap.action_erase_events(remapping_action)
		InputMap.action_add_event(remapping_action, event)
		
		_update_button_text_for_action(remapping_button)
		remapping_button = null
		remapping_action = ""
		tooltip_label.visible = false
