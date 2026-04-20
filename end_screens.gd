class_name EndScreens
extends CanvasLayer


signal retry_pressed
signal endless_mode_pressed


@onready var game_over_screen: Control = $GameOverScreen
@onready var victory_screen: Control = $VictoryScreen
@onready var retry_button: Button = $GameOverScreen/VBoxContainer/RetryButton
@onready var endless_mode_button: Button = $VictoryScreen/VBoxContainer/EndlessModeButton


func _ready() -> void:
	game_over_screen.hide()
	victory_screen.hide()
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	endless_mode_button.pressed.connect(func() -> void: endless_mode_pressed.emit())


func show_game_over() -> void:
	game_over_screen.show()


func show_victory() -> void:
	victory_screen.show()


func hide_all() -> void:
	game_over_screen.hide()
	victory_screen.hide()
