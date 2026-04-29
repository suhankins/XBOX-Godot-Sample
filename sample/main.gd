extends Control
## Main demo scene — shows GDK status, user info, and full gamepad visualizer.
## Gracefully degrades when C++ GDK singletons are not available.

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var user_label: Label = $VBoxContainer/UserLabel
@onready var gamertag_label: Label = $VBoxContainer/UserPanel/UserHBox/GamertagLabel
@onready var xuid_label: Label = $VBoxContainer/UserPanel/UserHBox/XuidLabel
@onready var avatar_rect: TextureRect = $VBoxContainer/UserPanel/UserHBox/AvatarRect
@onready var input_label: Label = $VBoxContainer/InputLabel
@onready var sign_in_button: Button = $VBoxContainer/SignInButton
@onready var haptics_toggle: CheckButton = $VBoxContainer/HapticsToggle
@onready var achievement_button: Button = $VBoxContainer/AchievementButton
@onready var achievement_label: Label = $VBoxContainer/AchievementLabel
@onready var gamepad_display: RichTextLabel = $VBoxContainer/GamepadDisplay

# ── Haptics state ───────────────────────────────────────────────
var haptics_enabled := false
var jolt_timer := 0.0
var x_was_pressed := false
var a_was_pressed := false
const JOLT_DURATION := 0.15

# ── Config ──────────────────────────────────────────────────────
var demo_achievement_id := "1"

# Runtime singleton references (null when C++ extensions aren't loaded)
var _gdk: Object = null
var _gdk_user: Object = null
var _gdk_input: Object = null
var _gdk_achievements: Object = null

func _ready() -> void:
	# Resolve singletons
	if Engine.has_singleton("GDK"):
		_gdk = Engine.get_singleton("GDK")
	if Engine.has_singleton("GDKUser"):
		_gdk_user = Engine.get_singleton("GDKUser")
	if Engine.has_singleton("GDKInput"):
		_gdk_input = Engine.get_singleton("GDKInput")
	if Engine.has_singleton("GDKAchievements"):
		_gdk_achievements = Engine.get_singleton("GDKAchievements")

	# Load config
	var cfg := ConfigFile.new()
	if cfg.load("res://sample_config.cfg") == OK:
		demo_achievement_id = cfg.get_value("achievements", "demo_achievement_id", "1")

	sign_in_button.pressed.connect(_on_sign_in_pressed)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	achievement_button.pressed.connect(_on_achievement_pressed)

	# Give the haptics toggle initial focus so gamepad can reach it immediately
	haptics_toggle.grab_focus()

	if _gdk == null:
		status_label.text = "GDK: Not loaded (C++ extension not compiled)"
		input_label.text = "Controllers: N/A"
		sign_in_button.disabled = true
		achievement_button.disabled = true
		return

	# Read initial state (signals may have fired before we connected)
	if _gdk.is_initialized():
		status_label.text = "GDK: Initialized ✓"
	if _gdk_input:
		input_label.text = "Controllers: %d" % _gdk_input.get_connected_device_count()
	if _gdk_user and _gdk_user.is_signed_in():
		var user = _gdk_user.get_current_user()
		if user:
			_show_user(user)
			sign_in_button.disabled = true
			sign_in_button.text = "Signed In"
			_gdk_user.get_gamer_picture()
			if _gdk_achievements and _gdk_achievements.is_initialized():
				_gdk_achievements.check_achievement(demo_achievement_id)

	_gdk.connect("initialized", func():
		status_label.text = "GDK: Initialized ✓"
	)
	_gdk.connect("error_occurred", func(msg):
		status_label.text = "GDK Error: " + msg
	)
	if _gdk_user:
		_gdk_user.connect("user_signed_in", func(user):
			_show_user(user)
			sign_in_button.disabled = true
			sign_in_button.text = "Signed In"
			_gdk_user.get_gamer_picture()
			if _gdk_achievements and _gdk_achievements.is_initialized():
				_gdk_achievements.check_achievement(demo_achievement_id)
		)
		_gdk_user.connect("sign_in_failed", func(error):
			gamertag_label.text = "Sign-in failed"
			xuid_label.text = ""
			sign_in_button.disabled = false
		)
		_gdk_user.connect("gamer_picture_loaded", func(texture):
			avatar_rect.texture = texture
			avatar_rect.visible = true
		)
	if _gdk_achievements:
		_gdk_achievements.connect("achievement_unlocked", func(id):
			achievement_label.text = "✅ Achievement unlocked!"
			achievement_button.text = "🏆 Achievement Unlocked!"
			achievement_button.disabled = true
		)
		_gdk_achievements.connect("achievement_update_failed", func(id, error):
			achievement_label.text = "❌ " + error
			achievement_button.disabled = false
		)
		_gdk_achievements.connect("achievement_checked", func(id, is_unlocked):
			if is_unlocked:
				achievement_button.text = "🏆 Already Unlocked"
				achievement_button.disabled = true
				achievement_label.text = "Achievement previously earned"
			else:
				achievement_button.disabled = false
		)
	if _gdk_input:
		_gdk_input.connect("device_connected", func(id):
			input_label.text = "Controllers: %d" % _gdk_input.get_connected_device_count()
		)
		_gdk_input.connect("device_disconnected", func(id):
			input_label.text = "Controllers: %d" % _gdk_input.get_connected_device_count()
		)

# Intercept joypad A so the CheckButton doesn't double-toggle from
# Godot's native joypad driver AND our GameInput injection.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()

func _show_user(user) -> void:
	gamertag_label.text = user.gamertag if user.gamertag else "Unknown"
	xuid_label.text = "XUID: %d" % user.xuid

func _on_sign_in_pressed() -> void:
	sign_in_button.disabled = true
	sign_in_button.text = "Signing in..."
	if _gdk_user:
		_gdk_user.sign_in()

func _on_achievement_pressed() -> void:
	achievement_button.disabled = true
	achievement_button.text = "Unlocking..."
	achievement_label.text = ""
	if _gdk_achievements:
		_gdk_achievements.unlock(demo_achievement_id)

func _on_haptics_toggled(enabled: bool) -> void:
	haptics_enabled = enabled
	if not enabled and _gdk_input and _gdk_input.get_connected_device_count() > 0:
		_gdk_input.stop_rumble(0)

# ── Gamepad Visualizer ──────────────────────────────────────────

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
	JOY_BUTTON_DPAD_UP: "D↑",
	JOY_BUTTON_DPAD_DOWN: "D↓",
	JOY_BUTTON_DPAD_LEFT: "D←",
	JOY_BUTTON_DPAD_RIGHT: "D→",
	JOY_BUTTON_GUIDE: "Xbox",
}

func _btn(joy: int, btn: JoyButton) -> String:
	var name: String = BUTTON_NAMES.get(btn, "?")
	if Input.is_joy_button_pressed(joy, btn):
		return "[color=lime][b]%s[/b][/color]" % name
	return "[color=gray]%s[/color]" % name

func _axis_bar(value: float, width: int = 10) -> String:
	var center := width / 2
	var pos := int(clampf((value + 1.0) * 0.5 * width, 0, width))
	var bar := ""
	for i in range(width + 1):
		if i == pos:
			bar += "[color=lime]█[/color]"
		elif i == center:
			bar += "[color=gray]│[/color]"
		else:
			bar += "[color=gray]·[/color]"
	return bar

func _trigger_bar(value: float, width: int = 10) -> String:
	var filled := int(clampf(value * width, 0, width))
	var bar := ""
	for i in range(width):
		if i < filled:
			bar += "[color=lime]█[/color]"
		else:
			bar += "[color=gray]·[/color]"
	return bar

func _process(_delta: float) -> void:
	if _gdk_input == null or _gdk_input.get_connected_device_count() == 0:
		gamepad_display.text = "[center][color=gray]No controller connected\nPlug in an Xbox controller via USB or Bluetooth[/color][/center]"
		return

	var joy := 0

	# A-button → toggle haptics (edge-detected, immune to double-events)
	var a_pressed := Input.is_joy_button_pressed(joy, JOY_BUTTON_A)
	if a_pressed and not a_was_pressed and haptics_toggle.has_focus():
		haptics_toggle.button_pressed = !haptics_toggle.button_pressed
		_on_haptics_toggled(haptics_toggle.button_pressed)
	a_was_pressed = a_pressed

	var lx := Input.get_joy_axis(joy, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y)
	var rx := Input.get_joy_axis(joy, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(joy, JOY_AXIS_RIGHT_Y)
	var lt := Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_RIGHT)

	var t := ""

	# Header
	var joy_name := Input.get_joy_name(joy)
	if joy_name.is_empty():
		joy_name = "Xbox Controller"
	t += "[b]%s (Joy %d)[/b]\n\n" % [joy_name, joy]

	# Shoulders & Triggers
	t += "  %s                            %s\n" % [_btn(joy, JOY_BUTTON_LEFT_SHOULDER), _btn(joy, JOY_BUTTON_RIGHT_SHOULDER)]
	t += "  LT [%s] %4.1f     RT [%s] %4.1f\n\n" % [_trigger_bar(lt, 8), lt, _trigger_bar(rt, 8), rt]

	# Face buttons + D-Pad layout
	t += "       %s                    %s\n" % [_btn(joy, JOY_BUTTON_DPAD_UP), _btn(joy, JOY_BUTTON_Y)]
	t += "    %s    %s    %s  %s     %s    %s\n" % [
		_btn(joy, JOY_BUTTON_DPAD_LEFT), _btn(joy, JOY_BUTTON_DPAD_RIGHT),
		_btn(joy, JOY_BUTTON_BACK), _btn(joy, JOY_BUTTON_START),
		_btn(joy, JOY_BUTTON_X), _btn(joy, JOY_BUTTON_B)]
	t += "       %s                    %s\n\n" % [_btn(joy, JOY_BUTTON_DPAD_DOWN), _btn(joy, JOY_BUTTON_A)]

	# Sticks
	var l_mag := sqrt(lx * lx + ly * ly)
	var r_mag := sqrt(rx * rx + ry * ry)
	t += "  Left Stick  %s  mag %4.2f\n" % [_btn(joy, JOY_BUTTON_LEFT_STICK), l_mag]
	t += "    X [%s] %+5.2f\n" % [_axis_bar(lx), lx]
	t += "    Y [%s] %+5.2f\n\n" % [_axis_bar(ly), ly]
	t += "  Right Stick %s  mag %4.2f\n" % [_btn(joy, JOY_BUTTON_RIGHT_STICK), r_mag]
	t += "    X [%s] %+5.2f\n" % [_axis_bar(rx), rx]
	t += "    Y [%s] %+5.2f\n\n" % [_axis_bar(ry), ry]

	# Guide button
	t += "  %s\n" % _btn(joy, JOY_BUTTON_GUIDE)

	# Haptics status
	if haptics_enabled:
		var x_pressed := Input.is_joy_button_pressed(joy, JOY_BUTTON_X)

		# Detect X press edge → start jolt
		if x_pressed and not x_was_pressed:
			jolt_timer = JOLT_DURATION
		x_was_pressed = x_pressed

		# Tick jolt timer
		if jolt_timer > 0.0:
			jolt_timer -= _delta

		# Compute rumble values
		var low_freq := 0.0
		var high_freq := 0.0
		if jolt_timer > 0.0:
			low_freq = 0.8
			high_freq = 1.0

		var rt_rumble := rt  # proportional to right trigger pull
		if _gdk_input:
			_gdk_input.set_rumble(joy, low_freq, high_freq, 0.0, rt_rumble)

		t += "\n  [color=yellow][b]Haptics ON[/b][/color]"
		if jolt_timer > 0.0:
			t += "  [color=lime]JOLT![/color]"
		if rt > 0.05:
			t += "  RT rumble: [color=lime]%3.0f%%[/color]" % (rt * 100.0)

	gamepad_display.text = t
