extends Control


@onready var main_menu_panel: VBoxContainer = %MainMenuPanel
@onready var settings_popup: Control = %SettingsPopup
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)
	settings_popup.back_pressed.connect(_on_back)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_settings() -> void:
	settings_popup.show()


func _on_back() -> void:
	settings_popup.hide()


func _on_exit() -> void:
	get_tree().quit()
