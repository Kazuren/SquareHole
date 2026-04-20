extends CanvasLayer


@onready var settings_popup: Control = $SettingsPopup


func _ready() -> void:
	settings_popup.hide()
	settings_popup.back_pressed.connect(_on_back)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_popup.visible:
		_on_back()
	elif get_tree().paused:
		# Another paused state (end screens); don't open settings on top.
		return
	else:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	get_tree().paused = true
	settings_popup.show()


func _on_back() -> void:
	settings_popup.hide()
	get_tree().paused = false
