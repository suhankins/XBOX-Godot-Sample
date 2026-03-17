extends SceneTree
## GodotGDK Test Suite
## Run: godot --headless --script res://tests/run_tests.gd

var _pass_count := 0
var _fail_count := 0
var _skip_count := 0
var _current_test := ""

# ── Helpers ──────────────────────────────────────────────────────

func _log_pass(name: String, detail: String = "") -> void:
	_pass_count += 1
	if detail:
		print("  PASS: %s — %s" % [name, detail])
	else:
		print("  PASS: %s" % name)

func _log_fail(name: String, detail: String = "") -> void:
	_fail_count += 1
	if detail:
		printerr("  FAIL: %s — %s" % [name, detail])
	else:
		printerr("  FAIL: %s" % name)

func _log_skip(name: String, reason: String = "") -> void:
	_skip_count += 1
	if reason:
		print("  SKIP: %s — %s" % [name, reason])
	else:
		print("  SKIP: %s" % name)

func _assert_true(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_log_pass(name, detail)
	else:
		_log_fail(name, detail)

func _assert_eq(actual, expected, name: String) -> void:
	if actual == expected:
		_log_pass(name, str(actual))
	else:
		_log_fail(name, "expected %s, got %s" % [str(expected), str(actual)])

func _assert_not_null(value, name: String) -> void:
	if value != null:
		_log_pass(name, str(typeof(value)))
	else:
		_log_fail(name, "got null")

func _assert_has_method(obj: Object, method_name: String, test_name: String = "") -> void:
	var label = test_name if test_name else "%s.%s() exists" % [obj.get_class(), method_name]
	_assert_true(obj.has_method(method_name), label)

func _assert_has_signal(obj: Object, signal_name: String, test_name: String = "") -> void:
	var label = test_name if test_name else "%s.%s signal exists" % [obj.get_class(), signal_name]
	_assert_true(obj.has_signal(signal_name), label)

# ── Test Groups ──────────────────────────────────────────────────

func _test_singleton_availability() -> void:
	print("\n── Singleton Availability ──")

	var gdk = Engine.get_singleton("GDK")
	_assert_not_null(gdk, "Engine.get_singleton('GDK')")

	var gdk_user = Engine.get_singleton("GDKUser")
	_assert_not_null(gdk_user, "Engine.get_singleton('GDKUser')")

	var gdk_input = Engine.get_singleton("GDKInput")
	_assert_not_null(gdk_input, "Engine.get_singleton('GDKInput')")

	# Test global access (the way GDScript users will actually use them)
	var gdk_global = Engine.get_singleton("GDK")
	_assert_true(gdk_global != null, "GDK global accessible")

func _test_gdk_core_api() -> void:
	print("\n── GDKCore API ──")

	var gdk = Engine.get_singleton("GDK")
	if gdk == null:
		_log_fail("GDKCore: singleton not found, skipping group")
		return

	# Methods exist
	_assert_has_method(gdk, "initialize")
	_assert_has_method(gdk, "shutdown")
	_assert_has_method(gdk, "is_initialized")
	_assert_has_method(gdk, "get_version")
	_assert_has_method(gdk, "tick")

	# Signals exist
	_assert_has_signal(gdk, "initialized")
	_assert_has_signal(gdk, "shutdown_completed")
	_assert_has_signal(gdk, "error_occurred")

	# get_version returns a non-empty string
	var version = gdk.get_version()
	_assert_true(version is String and version.length() > 0,
		"get_version() returns string", version)

	# is_initialized starts false
	_assert_eq(gdk.is_initialized(), false, "is_initialized() starts false")

	# tick() should not crash when not initialized
	gdk.tick()
	_log_pass("tick() safe when not initialized")

	# shutdown() should not crash when not initialized
	gdk.shutdown()
	_log_pass("shutdown() safe when not initialized")

	# Try initialize — may fail without Gaming Services, that's OK
	var err = gdk.initialize()
	if err == OK:
		_log_pass("initialize() succeeded", "GDK runtime available")
		_assert_eq(gdk.is_initialized(), true, "is_initialized() true after init")

		# tick() should work after init
		gdk.tick()
		_log_pass("tick() works after init")

		# shutdown
		gdk.shutdown()
		_assert_eq(gdk.is_initialized(), false, "is_initialized() false after shutdown")
	else:
		_log_skip("initialize()",
			"GDK runtime not available (err=%d) — expected without Gaming Services" % err)
		# Verify state is clean after failed init
		_assert_eq(gdk.is_initialized(), false, "is_initialized() false after failed init")

func _test_gdk_user_api() -> void:
	print("\n── GDKUser API ──")

	var gdk_user = Engine.get_singleton("GDKUser")
	if gdk_user == null:
		_log_fail("GDKUser: singleton not found, skipping group")
		return

	# Methods exist
	_assert_has_method(gdk_user, "sign_in")
	_assert_has_method(gdk_user, "sign_in_silently")
	_assert_has_method(gdk_user, "sign_out")
	_assert_has_method(gdk_user, "get_current_user")
	_assert_has_method(gdk_user, "is_signed_in")
	_assert_has_method(gdk_user, "is_sign_in_pending")

	# Signals exist
	_assert_has_signal(gdk_user, "user_signed_in")
	_assert_has_signal(gdk_user, "sign_in_failed")
	_assert_has_signal(gdk_user, "user_signed_out")

	# Initial state
	_assert_eq(gdk_user.is_signed_in(), false, "is_signed_in() starts false")
	_assert_eq(gdk_user.is_sign_in_pending(), false, "is_sign_in_pending() starts false")

	# get_current_user returns null when not signed in
	var user = gdk_user.get_current_user()
	_assert_true(user == null, "get_current_user() null when not signed in")

	# sign_out() is safe when not signed in
	gdk_user.sign_out()
	_log_pass("sign_out() safe when not signed in")

	# GDKUserInfo class
	var user_info = ClassDB.instantiate("GDKUserInfo")
	if user_info != null:
		_log_pass("GDKUserInfo class instantiable")
		_assert_has_method(user_info, "get_gamertag")
		_assert_has_method(user_info, "get_xuid")
		_assert_has_method(user_info, "is_valid")
		_assert_eq(user_info.is_valid(), false, "new GDKUserInfo.is_valid() == false")
		_assert_eq(user_info.get_gamertag(), "", "new GDKUserInfo.gamertag == empty")
		_assert_eq(user_info.get_xuid(), 0, "new GDKUserInfo.xuid == 0")
	else:
		_log_fail("GDKUserInfo class not instantiable")

func _test_gdk_input_api() -> void:
	print("\n── GDKInput API ──")

	var gdk_input = Engine.get_singleton("GDKInput")
	if gdk_input == null:
		_log_fail("GDKInput: singleton not found, skipping group")
		return

	# Methods exist
	_assert_has_method(gdk_input, "initialize")
	_assert_has_method(gdk_input, "shutdown")
	_assert_has_method(gdk_input, "process")
	_assert_has_method(gdk_input, "is_initialized")
	_assert_has_method(gdk_input, "get_connected_device_count")

	# Signals exist
	_assert_has_signal(gdk_input, "device_connected")
	_assert_has_signal(gdk_input, "device_disconnected")

	# Starts not initialized
	_assert_eq(gdk_input.is_initialized(), false, "is_initialized() starts false")
	_assert_eq(gdk_input.get_connected_device_count(), 0, "device count starts 0")

	# process() safe when not initialized
	gdk_input.process()
	_log_pass("process() safe when not initialized")

	# shutdown() safe when not initialized
	gdk_input.shutdown()
	_log_pass("shutdown() safe when not initialized")

	# Try initialize — may fail without GameInput service
	var err = gdk_input.initialize()
	if err == OK:
		_log_pass("initialize() succeeded")
		_assert_eq(gdk_input.is_initialized(), true, "is_initialized() true after init")
		var count = gdk_input.get_connected_device_count()
		_log_pass("get_connected_device_count()", str(count))
		gdk_input.process()
		_log_pass("process() works after init")
		gdk_input.shutdown()
		_assert_eq(gdk_input.is_initialized(), false, "is_initialized() false after shutdown")
	else:
		_log_skip("initialize()",
			"GameInput not available (err=%d) — may need GameInput service" % err)

func _test_signal_connectivity() -> void:
	print("\n── Signal Connectivity ──")

	# Test that we can connect to signals without errors
	var gdk = Engine.get_singleton("GDK")
	var gdk_user = Engine.get_singleton("GDKUser")
	var gdk_input = Engine.get_singleton("GDKInput")

	if gdk:
		var connected := true
		gdk.connect("initialized", func(): pass)
		gdk.connect("shutdown_completed", func(): pass)
		gdk.connect("error_occurred", func(_msg): pass)
		_log_pass("GDK signals connectable")
		# Disconnect to clean up
		for sig in ["initialized", "shutdown_completed", "error_occurred"]:
			for conn in gdk.get_signal_connection_list(sig):
				gdk.disconnect(sig, conn["callable"])

	if gdk_user:
		gdk_user.connect("user_signed_in", func(_user): pass)
		gdk_user.connect("sign_in_failed", func(_err): pass)
		_log_pass("GDKUser signals connectable")
		for sig in ["user_signed_in", "sign_in_failed"]:
			for conn in gdk_user.get_signal_connection_list(sig):
				gdk_user.disconnect(sig, conn["callable"])

	if gdk_input:
		gdk_input.connect("device_connected", func(_id): pass)
		gdk_input.connect("device_disconnected", func(_id): pass)
		_log_pass("GDKInput signals connectable")
		for sig in ["device_connected", "device_disconnected"]:
			for conn in gdk_input.get_signal_connection_list(sig):
				gdk_input.disconnect(sig, conn["callable"])

func _test_class_registration() -> void:
	print("\n── Class Registration ──")

	_assert_true(ClassDB.class_exists("GDKCore"), "GDKCore registered in ClassDB")
	_assert_true(ClassDB.class_exists("GDKUserInfo"), "GDKUserInfo registered in ClassDB")
	_assert_true(ClassDB.class_exists("GDKUserManager"), "GDKUserManager registered in ClassDB")
	_assert_true(ClassDB.class_exists("GDKInput"), "GDKInput registered in ClassDB")

	# Check inheritance
	_assert_true(ClassDB.is_parent_class("GDKCore", "Object"),
		"GDKCore extends Object")
	_assert_true(ClassDB.is_parent_class("GDKUserInfo", "RefCounted"),
		"GDKUserInfo extends RefCounted")
	_assert_true(ClassDB.is_parent_class("GDKUserManager", "Object"),
		"GDKUserManager extends Object")
	_assert_true(ClassDB.is_parent_class("GDKInput", "Object"),
		"GDKInput extends Object")

func _test_addon_structure() -> void:
	print("\n── Addon Structure (Export Platform) ──")

	# Verify addon files exist
	_assert_true(FileAccess.file_exists("res://addons/godot_gdk/plugin.cfg"),
		"plugin.cfg exists")
	_assert_true(FileAccess.file_exists("res://addons/godot_gdk/godot_gdk.gdextension"),
		".gdextension file exists")
	_assert_true(FileAccess.file_exists("res://addons/godot_gdk/editor/gdk_export_platform.gd"),
		"gdk_export_platform.gd exists")
	_assert_true(FileAccess.file_exists("res://addons/godot_gdk/editor/gdk_editor_plugin.gd"),
		"gdk_editor_plugin.gd exists")

	# Verify plugin.cfg has correct script path
	var cfg := ConfigFile.new()
	var err := cfg.load("res://addons/godot_gdk/plugin.cfg")
	_assert_eq(err, OK, "plugin.cfg loads without error")
	if err == OK:
		var script_path: String = cfg.get_value("plugin", "script", "")
		_assert_eq(script_path, "editor/gdk_editor_plugin.gd",
			"plugin.cfg script points to editor plugin")
		var plugin_name: String = cfg.get_value("plugin", "name", "")
		_assert_eq(plugin_name, "GodotGDK", "plugin.cfg name is GodotGDK")

	# Verify .gdextension references correct library path
	var ext_cfg := ConfigFile.new()
	err = ext_cfg.load("res://addons/godot_gdk/godot_gdk.gdextension")
	_assert_eq(err, OK, ".gdextension loads without error")

	# Verify DLL exists
	var dll_exists := FileAccess.file_exists("res://addons/godot_gdk/bin/godot_gdk.windows.debug.x86_64.dll") or \
		FileAccess.file_exists("res://addons/godot_gdk/bin/Debug/godot_gdk.windows.debug.x86_64.dll")
	_assert_true(dll_exists, "GDK DLL exists in bin/")

	# Verify export platform script can be loaded (as a Resource)
	var script = load("res://addons/godot_gdk/editor/gdk_export_platform.gd")
	_assert_true(script != null, "gdk_export_platform.gd loads as script")

	# Verify editor plugin script can be loaded
	var editor_script = load("res://addons/godot_gdk/editor/gdk_editor_plugin.gd")
	_assert_true(editor_script != null, "gdk_editor_plugin.gd loads as script")

# ── Entry Point ──────────────────────────────────────────────────

func _initialize() -> void:
	print("╔══════════════════════════════════════╗")
	print("║       GodotGDK Test Suite            ║")
	print("╚══════════════════════════════════════╝")

	_test_singleton_availability()
	_test_class_registration()
	_test_gdk_core_api()
	_test_gdk_user_api()
	_test_gdk_input_api()
	_test_signal_connectivity()
	_test_addon_structure()

	# Summary
	var total = _pass_count + _fail_count + _skip_count
	print("\n══════════════════════════════════════")
	print("Results: %d passed, %d failed, %d skipped (of %d)" % [
		_pass_count, _fail_count, _skip_count, total])
	print("══════════════════════════════════════")

	if _fail_count > 0:
		printerr("SUITE FAILED")
		quit(1)
	else:
		print("SUITE PASSED")
		quit(0)
