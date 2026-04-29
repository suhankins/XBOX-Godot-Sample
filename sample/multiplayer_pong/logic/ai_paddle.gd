extends Area2D
## Simple AI paddle that tracks the ball position with a reaction delay.

const MOTION_SPEED = 150
const REACTION_DISTANCE = 40.0

var _motion := 0.0

@onready var _screen_size_y := get_viewport_rect().size.y

func _process(delta: float) -> void:
	var ball = get_node_or_null(^"../Ball")
	if ball == null:
		return

	var diff = ball.position.y - position.y
	if absf(diff) > REACTION_DISTANCE:
		_motion = signf(diff) * MOTION_SPEED
	else:
		_motion = 0.0

	translate(Vector2(0.0, _motion * delta))
	position.y = clampf(position.y, 16, _screen_size_y - 16)


func _on_paddle_area_enter(area: Area2D) -> void:
	area.bounce(false, randf())
