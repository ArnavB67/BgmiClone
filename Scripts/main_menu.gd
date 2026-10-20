extends Node3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var turn_table: Node3D = $TurnTable
@onready var csg_cylinder_3d: CSGCylinder3D = $TurnTable/CSGCylinder3D
@onready var title_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var bot_count_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/BotCountLabel
@onready var bot_count_slider: HSlider = $CanvasLayer/MarginContainer/VBoxContainer/BotCountSlider
@onready var play_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/PlayButton
@onready var controls_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/ControlsButton
@onready var quit_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/QuitButton
@onready var controls_panel: Panel = $CanvasLayer/ControlsPanel

var NoOfBots = 15
var CameraTime= 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	CameraTime += delta
	if turn_table:
		turn_table.rotate_y(0.45 * delta)
	if camera_3d:
		camera_3d.position.y = 2.2 + sin(CameraTime * 1.5) * 0.12

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_level.tscn")

func _on_controls_button_pressed() -> void:
	if controls_panel:
		controls_panel.visible = not controls_panel.visible

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_bot_count_slider_value_changed(value: float) -> void:
	NoOfBots = int(value)
	if bot_count_label:
		bot_count_label.text = "Bot Count: %d" % NoOfBots
