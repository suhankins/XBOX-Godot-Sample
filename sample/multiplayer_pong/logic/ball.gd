extends Area2D

const DEFAULT_SPEED = 100.0

var direction := Vector2.LEFT
var stopped: bool = false
var _speed := DEFAULT_SPEED

@onready var _screen_size := get_viewport_rect().size


func _is_local_game() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func _process(delta: float) -> void:
	_speed += delta
	if not stopped:
		translate(_speed * delta * direction)

	# Check screen bounds to make ball bounce.
	var ball_pos := position
	if (ball_pos.y < 0 and direction.y < 0) or (ball_pos.y > _screen_size.y and direction.y > 0):
		direction.y = -direction.y

	if _is_local_game():
		# Single-player: handle both sides locally.
		if ball_pos.x < 0:
			get_parent().update_score(false)
			_reset_ball(false)
		elif ball_pos.x > _screen_size.x:
			get_parent().update_score(true)
			_reset_ball(true)
	elif is_multiplayer_authority():
		if ball_pos.x < 0:
			get_parent().update_score.rpc(false)
			_reset_ball.rpc(false)
	else:
		if ball_pos.x > _screen_size.x:
			get_parent().update_score.rpc(true)
			_reset_ball.rpc(true)


@rpc("any_peer", "call_local")
func bounce(left: bool, random: float) -> void:
	if left:
		direction.x = abs(direction.x)
	else:
		direction.x = -abs(direction.x)

	_speed *= 1.1
	direction.y = random * 2.0 - 1
	direction = direction.normalized()


@rpc("any_peer", "call_local")
func stop() -> void:
	stopped = true


@rpc("any_peer", "call_local")
func _reset_ball(for_left: float) -> void:
	position = _screen_size / 2
	if for_left:
		direction = Vector2.LEFT
	else:
		direction = Vector2.RIGHT
	_speed = DEFAULT_SPEED
