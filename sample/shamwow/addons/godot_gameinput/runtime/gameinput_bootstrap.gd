extends Node
## Godot GameInput — Bootstrap autoload
##
## Installed by `GameInputEditorPlugin`. Reads Project Settings and:
##  * Calls `GameInput.initialize()` if `game_input/runtime/initialize_on_startup` is true.
##  * Calls `GameInput.poll()` every `_process` if `game_input/runtime/auto_poll` is true.
##  * Calls `GameInput.shutdown()` when the tree is being torn down.
##
## Apps that need finer control can leave the settings disabled and call the API
## directly. `GameInputMapper` nodes also call `poll()` defensively (it's
## per-frame idempotent), so adding a Mapper to a scene is enough even when the
## bootstrap's `auto_poll` is off.

const SETTING_INITIALIZE_ON_STARTUP := "game_input/runtime/initialize_on_startup"
const SETTING_AUTO_POLL := "game_input/runtime/auto_poll"

var _auto_poll: bool = false
var _initialized_here: bool = false


func _ready() -> void:
	if not Engine.has_singleton("GameInput"):
		push_warning("[GameInput] Bootstrap: 'GameInput' singleton not registered. " +
				"Is the godot_gameinput GDExtension built and loaded?")
		set_process(false)
		return

	_auto_poll = bool(ProjectSettings.get_setting(SETTING_AUTO_POLL, true))

	var initialize_on_startup := bool(
			ProjectSettings.get_setting(SETTING_INITIALIZE_ON_STARTUP, false))
	if initialize_on_startup:
		var gi := Engine.get_singleton("GameInput")
		if gi.is_initialized():
			# Editor reload or another caller already initialised it — skip.
			pass
		elif gi.initialize():
			_initialized_here = true
			print("[GameInput] Bootstrap: GameInput.initialize() succeeded.")
		else:
			push_warning("[GameInput] Bootstrap: GameInput.initialize() failed. " +
					"Subsequent calls will return safe defaults.")

	set_process(_auto_poll)


func _process(_delta: float) -> void:
	if not _auto_poll:
		return
	var gi := Engine.get_singleton("GameInput")
	if gi != null:
		gi.poll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Only call shutdown() if WE initialized it. Otherwise leave it to the caller
		# that brought it up (e.g. tests, editor tooling).
		if _initialized_here and Engine.has_singleton("GameInput"):
			var gi := Engine.get_singleton("GameInput")
			if gi != null and gi.is_initialized():
				gi.shutdown()
				_initialized_here = false
