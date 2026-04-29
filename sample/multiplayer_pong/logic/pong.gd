extends Node2D

signal game_finished()

const SCORE_TO_WIN = 10
const AI_PADDLE_SCRIPT = preload("res://logic/ai_paddle.gd")

var score_left := 0
var score_right := 0
var is_single_player := false

@onready var player2: Area2D = $Player2
@onready var score_left_node: Label = $ScoreLeft
@onready var score_right_node: Label = $ScoreRight
@onready var winner_left: Label = $WinnerLeft
@onready var winner_right: Label = $WinnerRight

func _ready() -> void:
	if is_single_player:
		# Replace Player2's script with AI.
		player2.set_script(AI_PADDLE_SCRIPT)
		if player2.has_node("You"):
			player2.get_node("You").hide()
	else:
		if multiplayer.is_server():
			player2.set_multiplayer_authority(multiplayer.get_peers()[0])
		else:
			player2.set_multiplayer_authority(multiplayer.get_unique_id())

	print("Unique id: ", multiplayer.get_unique_id())


@rpc("any_peer", "call_local")
func update_score(add_to_left: int) -> void:
	if add_to_left:
		score_left += 1
		score_left_node.set_text(str(score_left))
	else:
		score_right += 1
		score_right_node.set_text(str(score_right))

	var game_ended: bool = false
	if score_left == SCORE_TO_WIN:
		winner_left.show()
		game_ended = true
	elif score_right == SCORE_TO_WIN:
		winner_right.show()
		game_ended = true

	if game_ended:
		$ExitGame.show()
		if is_single_player:
			$Ball.stop()
		else:
			$Ball.stop.rpc()


func _on_exit_game_pressed() -> void:
	game_finished.emit()
