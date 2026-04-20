class_name EndScreens
extends CanvasLayer


signal retry_pressed
signal endless_mode_pressed


@onready var game_over_screen: Control = $GameOverScreen
@onready var victory_screen: Control = $VictoryScreen
@onready var retry_button: Button = %RetryButton
@onready var endless_mode_button: Button = %EndlessModeButton
@onready var game_over_time_label: Label = %GameOverTimeLabel
@onready var victory_time_label: Label = %VictoryTimeLabel


func _ready() -> void:
	game_over_screen.hide()
	victory_screen.hide()
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	endless_mode_button.pressed.connect(func() -> void: endless_mode_pressed.emit())


func show_game_over(elapsed_seconds: float) -> void:
	game_over_time_label.text = "Survived: %s" % _format_time(elapsed_seconds)
	game_over_screen.show()


func show_victory(elapsed_seconds: float) -> void:
	victory_time_label.text = "Survived: %s" % _format_time(elapsed_seconds)
	victory_screen.show()


func hide_all() -> void:
	game_over_screen.hide()
	victory_screen.hide()


static func _format_time(seconds: float) -> String:
	var m: int = int(seconds / 60.0)
	var s: int = int(fmod(seconds, 60.0))
	return "%02d:%02d" % [m, s]
