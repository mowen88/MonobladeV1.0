extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
				
	await get_tree().create_timer(1.0).timeout
	transition_to_splash()
	
func transition_to_splash() -> void:
	StateManager.change_state(StateManager.GameState.SPLASH)
