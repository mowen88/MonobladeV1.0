extends Node

signal controller_connection_changed(is_connected: bool)

enum ControllerType { XBOX, PLAYSTATION, SWITCH, GENERIC }

const BUTTON_LABELS := {
	ControllerType.XBOX: {
		JOY_BUTTON_A: "A",
		JOY_BUTTON_B: "B",
		JOY_BUTTON_X: "X",
		JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "LS",
		JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_BACK: "View",
		JOY_BUTTON_START: "Menu",
		JOY_BUTTON_DPAD_UP: "D-Pad Up",
		JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
		JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
		JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	},
	ControllerType.PLAYSTATION: {
		JOY_BUTTON_A: "Cross",
		JOY_BUTTON_B: "Circle",
		JOY_BUTTON_X: "Square",
		JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_BACK: "Share",
		JOY_BUTTON_START: "Options",
		JOY_BUTTON_DPAD_UP: "D-Pad Up",
		JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
		JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
		JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
		20: "Touchpad" 
	},
	ControllerType.SWITCH: {
		JOY_BUTTON_A: "B",
		JOY_BUTTON_B: "A",
		JOY_BUTTON_X: "Y",
		JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L",
		JOY_BUTTON_RIGHT_SHOULDER: "R",
		JOY_BUTTON_LEFT_STICK: "L-Stick",
		JOY_BUTTON_RIGHT_STICK: "R-Stick",
		JOY_BUTTON_BACK: "-",
		JOY_BUTTON_START: "+",
		JOY_BUTTON_DPAD_UP: "D-Pad Up",
		JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
		JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
		JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	}
}

var has_controller: bool = false
var active_controller_id: int = -1
var controller_name: String = ""
var controller_type: ControllerType = ControllerType.GENERIC

var input_lock: bool = false
var cutscene_lock: bool = false

#func _input(_event: InputEvent) -> void:
	#if cutscene_lock:
		#return
		#
	#if input_lock:
		#get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Instantly drop any joypad event that doesn't belong to our active Player 1 device
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != active_controller_id:
		if event.is_pressed() or (event is InputEventJoypadMotion and abs(event.axis_value) >= 0.5):
			get_viewport().set_input_as_handled()
		return

	if input_lock:
		if event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton:
			if event.is_pressed():
				get_viewport().set_input_as_handled()

func get_joypad_event_label(event: InputEvent) -> String:
	# Fall back to Xbox layout for generic PC pads
	var active_type = controller_type if controller_type != ControllerType.GENERIC else ControllerType.XBOX
	
	if event is InputEventJoypadButton:
		var map = BUTTON_LABELS.get(active_type, BUTTON_LABELS[ControllerType.XBOX])
		return map.get(event.button_index, "Btn %d" % event.button_index)
		
	elif event is InputEventJoypadMotion:
		var dir = "+" if event.axis_value > 0 else "-"
		match event.axis:
			JOY_AXIS_LEFT_X: return "L-Stick " + ("Right" if event.axis_value > 0 else "Left")
			JOY_AXIS_LEFT_Y: return "L-Stick " + ("Down" if event.axis_value > 0 else "Up")
			JOY_AXIS_RIGHT_X: return "R-Stick " + ("Right" if event.axis_value > 0 else "Left")
			JOY_AXIS_RIGHT_Y: return "R-Stick " + ("Down" if event.axis_value > 0 else "Up")
			JOY_AXIS_TRIGGER_LEFT: return "L2" if active_type == ControllerType.PLAYSTATION else ("ZL" if active_type == ControllerType.SWITCH else "LT")
			JOY_AXIS_TRIGGER_RIGHT: return "R2" if active_type == ControllerType.PLAYSTATION else ("ZR" if active_type == ControllerType.SWITCH else "RT")
			_: return "Axis %d%s" % [event.axis, dir]
			
	return "Unassigned"
	
func _update_controller_state() -> void:
	
	var connected_pads = Input.get_connected_joypads()
	
	if connected_pads.is_empty():
		has_controller = false
		active_controller_id = -1
		controller_name = ""
		controller_type = ControllerType.GENERIC
	else:
		has_controller = true
		active_controller_id = connected_pads[0]
		controller_name = Input.get_joy_name(active_controller_id)
		controller_type = _detect_controller_type(controller_name)
		
	controller_connection_changed.emit(has_controller)

func _detect_controller_type(name: String) -> ControllerType:
	var lower_name = name.to_lower()
	
	# Check for PlayStation identifiers (including generic Bluetooth "Wireless Controller" names often used by DS4/DualSense)
	if "ps4" in lower_name or "sony" in lower_name or "dualshock" in lower_name or "dualsense" in lower_name or "playstation" in lower_name or "wireless controller" in lower_name:
		return ControllerType.PLAYSTATION
	elif "nintendo" in lower_name or "switch" in lower_name or "pro controller" in lower_name:
		return ControllerType.SWITCH
	elif "xinput" in lower_name or "xbox" in lower_name or "microsoft" in lower_name:
		return ControllerType.XBOX
		
	# Fallback: If it's connected on a platform or via a generic driver
	return ControllerType.GENERIC


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_controller_state()
