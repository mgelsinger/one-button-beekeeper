extends Node
## GameTest - Automated functional test for One Button Beekeeper
## Runs through core game systems and validates they work correctly

var main: Control
var tests_passed: int = 0
var tests_failed: int = 0
var test_log: Array[String] = []

func _ready() -> void:
	# Only run tests in autotest mode
	if not _is_autotest_mode():
		queue_free()
		return

	print("\n" + "=".repeat(50))
	print("GAME FUNCTIONAL TEST STARTING")
	print("=".repeat(50))

	# Wait a frame for Main scene to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Get reference to Main node
	main = get_tree().root.get_node_or_null("Main")
	if main == null:
		_fail("Could not find Main node")
		_finish_tests()
		return

	# Run all tests
	await _run_all_tests()
	_finish_tests()


func _is_autotest_mode() -> bool:
	if OS.has_feature("headless"):
		return true
	if "--autotest" in OS.get_cmdline_user_args():
		return true
	if "--autotest" in OS.get_cmdline_args():
		return true
	return false


func _run_all_tests() -> void:
	# Clear any existing save to ensure clean test state
	_clear_save_file()

	# Reset main to default state for testing
	_reset_main_state()

	_test_initial_state()
	await _test_honey_production()
	_test_collect_honey()
	_test_upgrade_costs()
	_test_purchase_upgrade()
	await _test_save_load()
	_test_visual_features()
	await _test_hive_full_state()


func _clear_save_file() -> void:
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")
		_log("Cleared existing save file for clean test")


func _reset_main_state() -> void:
	main.honey_total = 0
	main.hive_stored = 0.0
	for upgrade in main.upgrades:
		upgrade.level = 0
	main._recompute_derived_stats()
	main._update_all_ui()


func _test_initial_state() -> void:
	_log("TEST: Initial State")

	# Check base values
	if main.honey_total == 0:
		_pass("honey_total starts at 0")
	else:
		_fail("honey_total should be 0, got %d" % main.honey_total)

	if is_equal_approx(main.honey_per_second, 1.0):
		_pass("honey_per_second starts at 1.0")
	else:
		_fail("honey_per_second should be 1.0, got %.2f" % main.honey_per_second)

	if is_equal_approx(main.hive_storage_cap, 25.0):
		_pass("hive_storage_cap starts at 25.0")
	else:
		_fail("hive_storage_cap should be 25.0, got %.2f" % main.hive_storage_cap)

	if main.upgrades.size() == 3:
		_pass("3 upgrades defined")
	else:
		_fail("Should have 3 upgrades, got %d" % main.upgrades.size())


func _test_honey_production() -> void:
	_log("TEST: Honey Production")

	var initial_stored = main.hive_stored

	# Wait 0.5 seconds for production
	await get_tree().create_timer(0.5).timeout

	var after_stored = main.hive_stored
	var produced = after_stored - initial_stored

	# Should have produced approximately 0.5 honey (1.0/sec * 0.5 sec)
	if produced > 0.3 and produced < 0.7:
		_pass("Honey production working (produced %.2f in 0.5s)" % produced)
	else:
		_fail("Honey production incorrect, expected ~0.5, got %.2f" % produced)


func _test_collect_honey() -> void:
	_log("TEST: Collect Honey")

	# Set up a known state
	main.hive_stored = 10.5
	main.honey_total = 0

	# Simulate collect
	main._on_collect_pressed()

	if main.honey_total == 10:
		_pass("Collected 10 honey (floor of 10.5)")
	else:
		_fail("Should have collected 10 honey, got %d" % main.honey_total)

	if main.hive_stored < 0.1:
		_pass("Hive storage reset to 0")
	else:
		_fail("Hive storage should be 0, got %.2f" % main.hive_stored)


func _test_upgrade_costs() -> void:
	_log("TEST: Upgrade Cost Formula")

	var upgrade = main.upgrades[0]  # more_bees
	upgrade.level = 0

	var cost0 = main._get_upgrade_cost(upgrade)
	if cost0 == 10:
		_pass("Level 0 cost is 10 (base_cost)")
	else:
		_fail("Level 0 cost should be 10, got %d" % cost0)

	upgrade.level = 5
	var cost5 = main._get_upgrade_cost(upgrade)
	var expected = int(floor(10 * pow(1.25, 5)))  # Should be 30
	if cost5 == expected:
		_pass("Level 5 cost formula correct (%d)" % cost5)
	else:
		_fail("Level 5 cost should be %d, got %d" % [expected, cost5])

	upgrade.level = 0  # Reset


func _test_purchase_upgrade() -> void:
	_log("TEST: Purchase Upgrade")

	# Reset state
	for u in main.upgrades:
		u.level = 0
	main._recompute_derived_stats()

	main.honey_total = 100
	var initial_hps = main.honey_per_second

	# Buy "more_bees" upgrade
	main._on_upgrade_buy(0)

	if main.upgrades[0].level == 1:
		_pass("Upgrade level increased to 1")
	else:
		_fail("Upgrade level should be 1, got %d" % main.upgrades[0].level)

	if main.honey_total == 90:
		_pass("Honey decreased by cost (100 - 10 = 90)")
	else:
		_fail("Honey should be 90, got %d" % main.honey_total)

	if is_equal_approx(main.honey_per_second, initial_hps + 0.2):
		_pass("honey_per_second increased by 0.2")
	else:
		_fail("honey_per_second should be %.2f, got %.2f" % [initial_hps + 0.2, main.honey_per_second])


func _test_save_load() -> void:
	_log("TEST: Save/Load System")

	# Set specific state
	main.honey_total = 500
	main.hive_stored = 12.5
	main.upgrades[0].level = 3
	main.upgrades[1].level = 2
	main.upgrades[2].level = 1
	main._recompute_derived_stats()

	# Save
	main.save_game()
	_pass("Save completed without error")

	# Change state
	main.honey_total = 0
	main.hive_stored = 0
	for u in main.upgrades:
		u.level = 0

	# Load
	main.load_game()

	if main.honey_total == 500:
		_pass("honey_total loaded correctly (500)")
	else:
		_fail("honey_total should be 500, got %d" % main.honey_total)

	if main.upgrades[0].level == 3:
		_pass("Upgrade levels loaded correctly")
	else:
		_fail("more_bees level should be 3, got %d" % main.upgrades[0].level)

	# Check derived stats were recomputed
	var expected_hps = 1.0 + (3 * 0.2) + (1 * 0.5)  # base + more_bees + better_flowers
	if is_equal_approx(main.honey_per_second, expected_hps):
		_pass("Derived stats recomputed on load (%.2f)" % main.honey_per_second)
	else:
		_fail("honey_per_second should be %.2f, got %.2f" % [expected_hps, main.honey_per_second])

	# Clean up test save
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _test_visual_features() -> void:
	_log("TEST: Visual Features")

	# Reset state for visual tests
	for u in main.upgrades:
		u.level = 0
	main._recompute_derived_stats()
	main._refresh_all_visuals()

	# Test: Base bee count (1 bee at level 0)
	if main.bee_visuals.size() == 1:
		_pass("1 bee visible at more_bees level 0")
	else:
		_fail("Expected 1 bee at level 0, got %d" % main.bee_visuals.size())

	# Test: Upgrade more_bees increases bee count
	main.upgrades[0].level = 3  # more_bees
	main._refresh_bee_visuals()
	if main.bee_visuals.size() == 4:
		_pass("4 bees visible at more_bees level 3")
	else:
		_fail("Expected 4 bees at level 3, got %d" % main.bee_visuals.size())

	# Test: Flowers appear with better_flowers upgrade
	main.upgrades[2].level = 0  # better_flowers
	main._refresh_flower_visuals()
	if main.flower_visuals.size() == 0:
		_pass("0 flowers at better_flowers level 0")
	else:
		_fail("Expected 0 flowers at level 0, got %d" % main.flower_visuals.size())

	main.upgrades[2].level = 3
	main._refresh_flower_visuals()
	# Flower count = level * 2, so level 3 = 6 flowers
	if main.flower_visuals.size() == 6:
		_pass("6 flowers at better_flowers level 3 (level * 2)")
	else:
		_fail("Expected 6 flowers at level 3, got %d" % main.flower_visuals.size())

	# Reset for other tests
	for u in main.upgrades:
		u.level = 0
	main._recompute_derived_stats()
	main._refresh_all_visuals()


func _test_hive_full_state() -> void:
	_log("TEST: Hive Full Feedback")

	# Reset
	main.hive_stored = 0.0
	main.is_hive_full = false
	main._update_full_state()

	if not main.full_label.visible:
		_pass("FULL label hidden when hive not full")
	else:
		_fail("FULL label should be hidden when hive not full")

	# Fill the hive
	main.hive_stored = main.hive_storage_cap
	main._update_full_state()

	if main.is_hive_full:
		_pass("is_hive_full=true when storage at cap")
	else:
		_fail("is_hive_full should be true when storage at cap")

	if main.full_label.visible:
		_pass("FULL label visible when hive full")
	else:
		_fail("FULL label should be visible when hive full")

	# Collect to clear
	main._on_collect_pressed()
	await get_tree().process_frame
	main._update_full_state()

	if not main.is_hive_full:
		_pass("is_hive_full=false after collecting")
	else:
		_fail("is_hive_full should be false after collecting")


func _log(msg: String) -> void:
	print("\n" + msg)
	test_log.append(msg)


func _pass(msg: String) -> void:
	print("  [PASS] " + msg)
	test_log.append("  [PASS] " + msg)
	tests_passed += 1


func _fail(msg: String) -> void:
	print("  [FAIL] " + msg)
	test_log.append("  [FAIL] " + msg)
	tests_failed += 1


func _finish_tests() -> void:
	print("\n" + "=".repeat(50))
	print("TEST RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	print("=".repeat(50) + "\n")

	# Quit immediately with appropriate exit code
	var exit_code = 1 if tests_failed > 0 else 0
	get_tree().quit(exit_code)
