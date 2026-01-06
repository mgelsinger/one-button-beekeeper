extends Control
## Main game script for One Button Beekeeper
## Handles game state, upgrades, UI updates, visuals, and save/load

# Base stats (used for derived stat calculation)
const BASE_HONEY_PER_SECOND: float = 1.0
const BASE_HIVE_STORAGE_CAP: float = 25.0
const SAVE_PATH: String = "user://save.json"

# Visual constants
const MAX_VISIBLE_BEES: int = 8
const MAX_VISIBLE_FLOWERS: int = 12
const HIVE_BASE_SCALE: float = 1.0
const HIVE_SCALE_PER_LEVEL: float = 0.03
const HIVE_MAX_SCALE: float = 1.25

# Preloaded scenes
var FloatingTextScene: PackedScene = preload("res://scenes/FloatingText.tscn")
var bee_texture: Texture2D = preload("res://assets/sprites/bee.png")
var flower_texture: Texture2D = preload("res://assets/sprites/flower.png")

# Game state
var honey_total: int = 0
var hive_stored: float = 0.0

# Derived stats (recomputed from upgrades)
var honey_per_second: float = BASE_HONEY_PER_SECOND
var hive_storage_cap: float = BASE_HIVE_STORAGE_CAP

# Upgrade definitions
var upgrades: Array[Dictionary] = [
	{
		"id": "more_bees",
		"name": "More Bees",
		"base_cost": 10,
		"growth": 1.25,
		"level": 0,
		"effect_per_level": 0.2,
		"effect_stat": "honey_per_second",
		"effect_text": "+0.2 honey/sec"
	},
	{
		"id": "bigger_hive",
		"name": "Bigger Hive",
		"base_cost": 15,
		"growth": 1.28,
		"level": 0,
		"effect_per_level": 10.0,
		"effect_stat": "hive_storage_cap",
		"effect_text": "+10 hive capacity"
	},
	{
		"id": "better_flowers",
		"name": "Better Flowers",
		"base_cost": 30,
		"growth": 1.30,
		"level": 0,
		"effect_per_level": 0.5,
		"effect_stat": "honey_per_second",
		"effect_text": "+0.5 honey/sec"
	}
]

# Node references
@onready var honey_label: Label = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HoneyLabel
@onready var hive_label: Label = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveLabel
@onready var progress_bar: ProgressBar = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveProgress
@onready var collect_button: Button = $MainVBox/ContentMargin/ContentHBox/LeftColumn/CollectButton
@onready var hive_sprite: TextureRect = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveContainer/HiveSprite
@onready var hive_container: Control = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveContainer
@onready var flower_layer: Control = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveContainer/FlowerLayer
@onready var bee_layer: Control = $MainVBox/ContentMargin/ContentHBox/LeftColumn/HiveContainer/BeeLayer
@onready var upgrades_container: VBoxContainer = $MainVBox/ContentMargin/ContentHBox/RightColumn/UpgradesPanel/UpgradesVBox
@onready var left_column: VBoxContainer = $MainVBox/ContentMargin/ContentHBox/LeftColumn
@onready var settings_menu: PanelContainer = $SettingsMenu

# Visual state
var bee_visuals: Array[TextureRect] = []
var flower_visuals: Array[TextureRect] = []
var full_label: Label
var is_hive_full: bool = false
var full_pulse_tween: Tween

# Animation timing
var animation_time: float = 0.0

# UI update timer
var ui_timer: float = 0.0
const UI_UPDATE_INTERVAL: float = 0.1  # 10 Hz

# Autosave timer
var autosave_timer: Timer


func _ready() -> void:
	# Load saved game
	load_game()

	# Setup visual containers
	_setup_visual_containers()

	# Connect collect button
	collect_button.pressed.connect(_on_collect_pressed)

	# Setup upgrade UI
	_setup_upgrade_ui()

	# Refresh all visuals based on upgrade levels (deferred to ensure layout is ready)
	call_deferred("_refresh_all_visuals")

	# Initial UI update
	_update_all_ui()

	# Setup autosave timer (15 seconds)
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 15.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(autosave_timer)


func _process(delta: float) -> void:
	# Passive honey production
	hive_stored = minf(hive_stored + honey_per_second * delta, hive_storage_cap)

	# Animation timing for bees
	animation_time += delta

	# Animate all bee visuals with phase offsets
	for i in range(bee_visuals.size()):
		var bee = bee_visuals[i]
		if bee and is_instance_valid(bee):
			var phase_offset = i * 0.7  # Different phase for each bee
			var base_y = bee.get_meta("base_y", bee.position.y)
			bee.position.y = base_y + sin(animation_time * 2.0 + phase_offset) * 4.0

	# UI update at 10 Hz
	ui_timer += delta
	if ui_timer >= UI_UPDATE_INTERVAL:
		ui_timer = 0.0
		_update_hive_ui()
		_update_full_state()


func _setup_visual_containers() -> void:
	# Create "FULL" label (hidden by default)
	full_label = Label.new()
	full_label.text = "FULL!"
	full_label.add_theme_font_size_override("font_size", 18)
	full_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	full_label.visible = false
	# Insert after progress bar
	var progress_idx = progress_bar.get_index()
	left_column.add_child(full_label)
	left_column.move_child(full_label, progress_idx + 1)


func _setup_upgrade_ui() -> void:
	# Create UI for each upgrade
	for i in range(upgrades.size()):
		var upgrade = upgrades[i]
		var upgrade_panel = _create_upgrade_panel(upgrade, i)
		upgrades_container.add_child(upgrade_panel)


func _create_upgrade_panel(upgrade: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Name label
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = upgrade.name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Level label
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Level: %d" % upgrade.level
	level_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(level_label)

	# Effect label
	var effect_label = Label.new()
	effect_label.name = "EffectLabel"
	effect_label.text = upgrade.effect_text
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(effect_label)

	# Buy button - consistent sizing
	var buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "Buy (Cost: %d)" % _get_upgrade_cost(upgrade)
	buy_button.custom_minimum_size = Vector2(180, 32)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.pressed.connect(_on_upgrade_buy.bind(index))
	vbox.add_child(buy_button)

	return panel


func _get_upgrade_cost(upgrade: Dictionary) -> int:
	return int(floor(upgrade.base_cost * pow(upgrade.growth, upgrade.level)))


func _on_collect_pressed() -> void:
	var gained = int(floor(hive_stored))
	if gained > 0:
		AudioManager.play_collect()
		honey_total += gained
		hive_stored = 0.0
		_animate_honey_pop()
		_spawn_floating_text(gained)
		_update_all_ui()
		save_game()
	else:
		AudioManager.play_click()


func _on_upgrade_buy(upgrade_index: int) -> void:
	var upgrade = upgrades[upgrade_index]
	var cost = _get_upgrade_cost(upgrade)

	if honey_total >= cost:
		AudioManager.play_click()
		honey_total -= cost
		upgrade.level += 1
		_recompute_derived_stats()
		_refresh_all_visuals()
		_update_all_ui()
		save_game()


func _on_settings_button_pressed() -> void:
	AudioManager.play_click()
	settings_menu.show_menu()


func _on_autosave_timeout() -> void:
	save_game()


func _recompute_derived_stats() -> void:
	# Recompute honey_per_second
	honey_per_second = BASE_HONEY_PER_SECOND
	for upgrade in upgrades:
		if upgrade.effect_stat == "honey_per_second":
			honey_per_second += upgrade.level * upgrade.effect_per_level

	# Recompute hive_storage_cap
	hive_storage_cap = BASE_HIVE_STORAGE_CAP
	for upgrade in upgrades:
		if upgrade.effect_stat == "hive_storage_cap":
			hive_storage_cap += upgrade.level * upgrade.effect_per_level

	# Clamp hive_stored to new cap
	hive_stored = minf(hive_stored, hive_storage_cap)


func _refresh_all_visuals() -> void:
	_refresh_bee_visuals()
	_refresh_hive_scale()
	_refresh_flower_visuals()


func _refresh_bee_visuals() -> void:
	var more_bees_level = _get_upgrade_level("more_bees")
	# Start with 1 bee, add 1 per level, cap at MAX_VISIBLE_BEES
	var target_bee_count = mini(1 + more_bees_level, MAX_VISIBLE_BEES)

	# Remove all existing bees and recreate (ensures proper positioning)
	for bee in bee_visuals:
		if bee and is_instance_valid(bee):
			bee.queue_free()
	bee_visuals.clear()

	# Get the center of the hive container for positioning
	var container_size = bee_layer.size
	if container_size.x < 10:
		container_size = Vector2(300, 140)  # Fallback size
	var center = container_size / 2

	# Create bees positioned in a circle around the hive center
	for i in range(target_bee_count):
		var bee = _create_bee_visual(i, target_bee_count, center)
		bee_visuals.append(bee)
		bee_layer.add_child(bee)


func _create_bee_visual(index: int, total_count: int, center: Vector2) -> TextureRect:
	var bee = TextureRect.new()
	bee.texture = bee_texture
	bee.custom_minimum_size = Vector2(32, 32)
	bee.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bee.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Position bees evenly around the hive in a circle
	var angle = (TAU / max(total_count, 1)) * index - PI/2  # Start from top
	var radius = 50.0 + (index % 2) * 8  # Slight radius variation

	var pos_x = center.x + cos(angle) * radius - 16  # -16 to center the 32px bee
	var pos_y = center.y + sin(angle) * radius - 16

	# Clamp to stay within the layer bounds with padding
	var bounds_min = Vector2(8, 8)
	var bounds_max = bee_layer.size - Vector2(40, 40)
	if bounds_max.x < bounds_min.x:
		bounds_max.x = 260
	if bounds_max.y < bounds_min.y:
		bounds_max.y = 100

	pos_x = clampf(pos_x, bounds_min.x, bounds_max.x)
	pos_y = clampf(pos_y, bounds_min.y, bounds_max.y)

	bee.position = Vector2(pos_x, pos_y)

	# Store base position for bobbing animation
	bee.set_meta("base_y", bee.position.y)

	return bee


func _refresh_hive_scale() -> void:
	var bigger_hive_level = _get_upgrade_level("bigger_hive")
	var target_scale = minf(HIVE_BASE_SCALE + bigger_hive_level * HIVE_SCALE_PER_LEVEL, HIVE_MAX_SCALE)

	# Animate scale change smoothly
	var tween = create_tween()
	tween.tween_property(hive_sprite, "scale", Vector2(target_scale, target_scale), 0.3)


func _refresh_flower_visuals() -> void:
	var better_flowers_level = _get_upgrade_level("better_flowers")
	# Flowers = level * 2, capped at MAX_VISIBLE_FLOWERS
	var target_flower_count = mini(better_flowers_level * 2, MAX_VISIBLE_FLOWERS)

	# Remove all existing flowers and recreate
	for flower in flower_visuals:
		if flower and is_instance_valid(flower):
			flower.queue_free()
	flower_visuals.clear()

	# Get the flower layer size for positioning bounds
	var layer_size = flower_layer.size
	if layer_size.x < 10:
		layer_size = Vector2(300, 140)  # Fallback size

	# Create flowers scattered in the layer
	for i in range(target_flower_count):
		var flower = _create_flower_visual(i, layer_size, better_flowers_level)
		flower_visuals.append(flower)
		flower_layer.add_child(flower)


func _create_flower_visual(index: int, layer_size: Vector2, level: int) -> TextureRect:
	var flower = TextureRect.new()
	flower.texture = flower_texture
	flower.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flower.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flower.modulate.a = 0.5  # Subtle background decoration

	# Use deterministic pseudo-random positioning based on index and level
	# This ensures flowers don't reshuffle when adding new ones
	var seed_base = index * 1337 + 42
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_base

	# Random position within the layer bounds (with padding to avoid edges)
	var padding = 15.0
	var x_pos = rng.randf_range(padding, layer_size.x - padding - 20)
	var y_pos = rng.randf_range(padding, layer_size.y - padding - 20)

	flower.position = Vector2(x_pos, y_pos)

	# Random scale variation (0.7 to 1.2)
	var scale_factor = rng.randf_range(0.7, 1.2)
	flower.custom_minimum_size = Vector2(20 * scale_factor, 20 * scale_factor)

	# Random rotation
	flower.rotation = rng.randf_range(-0.3, 0.3)

	return flower


func _get_upgrade_level(upgrade_id: String) -> int:
	for upgrade in upgrades:
		if upgrade.id == upgrade_id:
			return upgrade.level
	return 0


func _spawn_floating_text(amount: int) -> void:
	var floating_text = FloatingTextScene.instantiate()
	# Position near the honey label
	floating_text.position = honey_label.global_position + Vector2(120, 0)
	get_tree().root.add_child(floating_text)
	floating_text.set_value(amount)


func _update_full_state() -> void:
	var was_full = is_hive_full
	is_hive_full = hive_stored >= hive_storage_cap - 0.01

	if is_hive_full and not was_full:
		# Just became full - show label and start pulse
		full_label.visible = true
		_start_full_pulse()
	elif not is_hive_full and was_full:
		# No longer full - hide label and stop pulse
		full_label.visible = false
		_stop_full_pulse()


func _start_full_pulse() -> void:
	if full_pulse_tween and full_pulse_tween.is_valid():
		full_pulse_tween.kill()

	full_pulse_tween = create_tween()
	full_pulse_tween.set_loops()
	full_pulse_tween.tween_property(progress_bar, "modulate", Color(1.2, 1.1, 0.8), 0.4)
	full_pulse_tween.tween_property(progress_bar, "modulate", Color(1.0, 1.0, 1.0), 0.4)


func _stop_full_pulse() -> void:
	if full_pulse_tween and full_pulse_tween.is_valid():
		full_pulse_tween.kill()
	progress_bar.modulate = Color(1.0, 1.0, 1.0)


func _update_all_ui() -> void:
	_update_honey_ui()
	_update_hive_ui()
	_update_upgrades_ui()


func _update_honey_ui() -> void:
	honey_label.text = "Honey: %d" % honey_total


func _update_hive_ui() -> void:
	hive_label.text = "Hive: %.1f / %.0f" % [hive_stored, hive_storage_cap]
	progress_bar.max_value = hive_storage_cap
	progress_bar.value = hive_stored


func _update_upgrades_ui() -> void:
	for i in range(upgrades.size()):
		var upgrade = upgrades[i]
		var panel = upgrades_container.get_child(i)
		var vbox = panel.get_child(0)

		var level_label = vbox.get_node("LevelLabel")
		var buy_button = vbox.get_node("BuyButton")

		var cost = _get_upgrade_cost(upgrade)
		level_label.text = "Level: %d" % upgrade.level
		buy_button.text = "Buy (Cost: %d)" % cost
		buy_button.disabled = honey_total < cost


func _animate_honey_pop() -> void:
	# Simple scale pop animation on honey label
	var tween = create_tween()
	tween.tween_property(honey_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(honey_label, "scale", Vector2(1.0, 1.0), 0.1)


func save_game() -> void:
	var save_data = {
		"honey_total": honey_total,
		"hive_stored": hive_stored,
		"upgrades": {}
	}

	for upgrade in upgrades:
		save_data.upgrades[upgrade.id] = upgrade.level

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_warning("Failed to parse save file, starting fresh")
		return

	var save_data = json.data
	if not save_data is Dictionary:
		push_warning("Invalid save data format, starting fresh")
		return

	# Load basic state
	honey_total = int(save_data.get("honey_total", 0))
	hive_stored = float(save_data.get("hive_stored", 0.0))

	# Load upgrade levels
	var saved_upgrades = save_data.get("upgrades", {})
	for upgrade in upgrades:
		if saved_upgrades.has(upgrade.id):
			upgrade.level = int(saved_upgrades[upgrade.id])

	# Recompute derived stats from loaded upgrade levels
	_recompute_derived_stats()
