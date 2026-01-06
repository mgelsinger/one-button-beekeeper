extends Node
## AutoQuit - Autoload singleton for automated testing
## Automatically quits the game after 5 seconds in headless mode or when --autotest is passed

func _ready() -> void:
	if _should_auto_quit():
		print("[AutoQuit] Headless/autotest mode detected, will quit in 5 seconds...")
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(_on_quit_timer_timeout)
		add_child(timer)
		timer.start()


func _should_auto_quit() -> bool:
	# Check for headless feature
	if OS.has_feature("headless"):
		return true

	# Check for --autotest in command line args
	var args = OS.get_cmdline_user_args()
	if "--autotest" in args:
		return true

	# Also check regular cmdline args
	var all_args = OS.get_cmdline_args()
	if "--autotest" in all_args:
		return true

	return false


func _on_quit_timer_timeout() -> void:
	print("[AutoQuit] Timer expired, quitting with exit code 0")
	get_tree().quit(0)
