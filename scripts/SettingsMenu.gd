extends PanelContainer
## SettingsMenu - Popup menu with volume control, reset save, and quit options

signal closed

const VERSION: String = "1.0.0"
const SAVE_PATH: String = "user://save.json"

@onready var volume_slider: HSlider = $MarginContainer/VBox/VolumeHBox/VolumeSlider
@onready var volume_label: Label = $MarginContainer/VBox/VolumeHBox/VolumeLabel
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog


func _ready() -> void:
	# Initialize volume slider from AudioManager
	volume_slider.value = AudioManager.get_master_volume() * 100.0
	_update_volume_label()

	# Connect signals
	volume_slider.value_changed.connect(_on_volume_changed)


func _on_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)
	_update_volume_label()
	AudioManager.play_click()


func _update_volume_label() -> void:
	volume_label.text = "%d%%" % int(volume_slider.value)


func _on_reset_button_pressed() -> void:
	AudioManager.play_click()
	confirm_dialog.dialog_text = "Are you sure you want to reset all progress?\nThis cannot be undone."
	confirm_dialog.popup_centered()


func _on_confirm_dialog_confirmed() -> void:
	# Delete save file
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")

	# Reload the scene to reset state
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	AudioManager.play_click()
	get_tree().quit()


func _on_close_button_pressed() -> void:
	AudioManager.play_click()
	closed.emit()
	hide()


func show_menu() -> void:
	# Refresh volume slider when showing
	volume_slider.value = AudioManager.get_master_volume() * 100.0
	_update_volume_label()
	show()
