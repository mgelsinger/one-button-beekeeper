extends Label
## FloatingText - Animated floating text that rises and fades out
## Used for "+X" feedback when collecting honey

func _ready() -> void:
	# Start invisible until set_value is called
	modulate.a = 0.0


func set_value(amount: int) -> void:
	text = "+%d" % amount
	modulate.a = 1.0

	# Animate upward movement and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)

	# Free the node when animation completes
	tween.chain().tween_callback(queue_free)
