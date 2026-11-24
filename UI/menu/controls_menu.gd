extends VBoxContainer

signal back_requested
signal input_map_requested(input_map_type: String)

func _ready() -> void:
	
	InputManager.controller_connection_changed.connect(func(_connected):_update_controller_button())
	_update_controller_button()
	
	for child in get_children():
		if child is Button:
			
			child.pressed.connect(_on_button_pressed.bind(child.name))
			#child.focus_mode = Control.FOCUS_NONE

func _update_controller_button() -> void:
	
	for child in get_children():
		if child is Button:
			if child.name == "ControllerButton":
				print(child)
				if InputManager.has_controller:
					child.disabled = false
				else:
					child.disabled = true
		
func _on_button_pressed(button_name: String) -> void:
	match button_name:

		"ControllerButton": 
			input_map_requested.emit("Controller")
		"KeyboardButton": 
			input_map_requested.emit("Keyboard")
		"BackButton":
			back_requested.emit()
