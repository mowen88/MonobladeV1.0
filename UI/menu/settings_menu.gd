extends VBoxContainer

signal start_game_requested
signal gameplay_requested
signal language_requested
signal controls_requested
signal audio_requested
signal back_requested

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

		"AudioButton": 
			audio_requested.emit()
		"GameplayButton": 
			gameplay_requested.emit()
		"LanguageButton": 
			language_requested.emit()
		"ControlsButton": 
			controls_requested.emit()
		"BackButton":
			back_requested.emit()
