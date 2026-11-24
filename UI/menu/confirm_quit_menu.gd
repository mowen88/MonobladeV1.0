extends VBoxContainer

signal confirm
signal cancel

func _ready() -> void:
	$ConfirmButton.pressed.connect(func(): confirm.emit())
	$CancelButton.pressed.connect(func(): cancel.emit())
