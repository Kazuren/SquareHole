extends Control


signal back_pressed


const CONFIG_PATH := "user://audio_settings.cfg"

const GOOD_SFX_1 = preload("res://Sound/Sfx/good1.wav")
const GOOD_SFX_2 = preload("res://Sound/Sfx/good2.wav")
const BAD_SFX_1 = preload("res://Sound/Sfx/bad1.wav")
const BAD_SFX_2 = preload("res://Sound/Sfx/bad2.wav")


@onready var master_slider: HSlider = %MasterSlider
@onready var back_button: Button = %SettingsBackButton
@onready var fullscreen_check: CheckBox = %FullscreenCheck

var preview_player: AudioStreamPlayer
var preview_pool: Array[AudioStream] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	# Preview plays on Master so it demonstrates the slider's effect directly.
	preview_player = AudioStreamPlayer.new()
	preview_player.bus = "Master"
	add_child(preview_player)
	preview_pool = [GOOD_SFX_1, GOOD_SFX_2, BAD_SFX_1, BAD_SFX_2, _make_heartbeat()]

	master_slider.value_changed.connect(_on_master_changed)
	master_slider.drag_ended.connect(_on_master_drag_ended)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	_load_settings()


func _on_master_changed(v: float) -> void:
	_apply_volume("Master", v)
	_save_settings()


func _on_master_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_play_preview()


func _play_preview() -> void:
	if preview_pool.is_empty():
		return
	preview_player.stream = preview_pool[rng.randi_range(0, preview_pool.size() - 1)]
	preview_player.play()


func _apply_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _on_fullscreen_toggled(pressed: bool) -> void:
	_apply_fullscreen(pressed)
	_save_settings()


func _apply_fullscreen(enabled: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var master_v: float = 1.0
	var fullscreen: bool = false
	if cfg.load(CONFIG_PATH) == OK:
		master_v = cfg.get_value("audio", "master", 1.0)
		fullscreen = cfg.get_value("display", "fullscreen", false)
	master_slider.value = master_v
	_apply_volume("Master", master_v)
	# no-signal so we don't trigger _on_fullscreen_toggled during init.
	fullscreen_check.set_pressed_no_signal(fullscreen)
	_apply_fullscreen(fullscreen)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_slider.value)
	cfg.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(CONFIG_PATH)


# Duplicated from main.gd so the popup can preview the heartbeat without
# depending on Main being loaded.
func _make_heartbeat() -> AudioStreamWAV:
	var sample_rate := 44100
	var total_samples := int(sample_rate * 0.4)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in total_samples:
		var t := float(i) / sample_rate
		var sample := 0.0
		if t < 0.15:
			sample = sin(TAU * 60.0 * t) * exp(-t * 18.0)
		elif t >= 0.22:
			var dt := t - 0.22
			sample = sin(TAU * 50.0 * dt) * exp(-dt * 14.0) * 0.7
		var v := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, v)

	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
