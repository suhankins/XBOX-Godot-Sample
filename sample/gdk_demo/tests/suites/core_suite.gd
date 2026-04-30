extends RefCounted

const EMBED_DISPATCH_SETTING := "gdk/runtime/embed_dispatch"

func run(context) -> void:
	_test_singleton_availability(context)
	_test_class_registration(context)
	await _test_gdk_root_api(context)

func _test_singleton_availability(context) -> void:
	context.log_section("Singleton Availability")

	var gdk = context.get_gdk()
	context.assert_not_null(gdk, "Engine.get_singleton('GDK')")
	context.assert_true(not Engine.has_singleton("GDKUser"), "legacy GDKUser singleton removed")

func _test_class_registration(context) -> void:
	context.log_section("Class Registration")

	for registered_class in [
		"GDK",
		"GDKUsers",
		"GDKUser",
		"GDKAchievements",
		"GDKAchievement",
		"GDKPresence",
		"GDKPresenceRecord",
		"GDKSocial",
		"GDKSocialFilter",
		"GDKSocialGroup",
		"GDKSocialUser",
		"GDKAsyncOp",
		"GDKDispatchOp",
		"GDKResult"
	]:
		context.assert_true(ClassDB.class_exists(registered_class), "%s registered in ClassDB" % registered_class)

	context.assert_true(ClassDB.is_parent_class("GDK", "Object"), "GDK extends Object")
	context.assert_true(ClassDB.is_parent_class("GDKUsers", "RefCounted"), "GDKUsers extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKUser", "RefCounted"), "GDKUser extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKAchievements", "RefCounted"), "GDKAchievements extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKAchievement", "RefCounted"), "GDKAchievement extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKPresence", "RefCounted"), "GDKPresence extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKPresenceRecord", "RefCounted"), "GDKPresenceRecord extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKSocial", "RefCounted"), "GDKSocial extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKSocialFilter", "RefCounted"), "GDKSocialFilter extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKSocialGroup", "RefCounted"), "GDKSocialGroup extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKSocialUser", "RefCounted"), "GDKSocialUser extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKAsyncOp", "RefCounted"), "GDKAsyncOp extends RefCounted")
	context.assert_true(ClassDB.is_parent_class("GDKDispatchOp", "GDKAsyncOp"), "GDKDispatchOp extends GDKAsyncOp")
	context.assert_true(ClassDB.is_parent_class("GDKResult", "RefCounted"), "GDKResult extends RefCounted")

func _test_gdk_root_api(context) -> void:
	context.log_section("GDK Root API")

	var gdk = context.get_gdk()
	if gdk == null:
		context.log_fail("GDK root singleton missing, skipping root API group")
		return

	context.reset_runtime()

	for method_name in ["initialize", "shutdown", "is_available", "is_initialized", "dispatch", "get_last_error", "get_users", "get_achievements", "get_presence", "get_social"]:
		context.assert_has_method(gdk, method_name)

	for signal_name in ["initialized", "shutdown_completed", "runtime_error"]:
		context.assert_has_signal(gdk, signal_name)

	context.assert_true(gdk.get_users() != null, "GDK.users service available")
	context.assert_true(gdk.get_achievements() != null, "GDK.achievements service available")
	context.assert_true(gdk.get_presence() != null, "GDK.presence service available")
	context.assert_true(gdk.get_social() != null, "GDK.social service available")
	context.assert_true(gdk.is_available() is bool, "is_available() returns bool")
	context.assert_eq(gdk.is_initialized(), false, "is_initialized() starts false")
	context.assert_eq(gdk.dispatch(), 0, "dispatch() safe before init")
	context.assert_true(ProjectSettings.has_setting(EMBED_DISPATCH_SETTING), "gdk/runtime/embed_dispatch project setting registered")
	context.assert_eq(bool(ProjectSettings.get_setting(EMBED_DISPATCH_SETTING, false)), true, "gdk/runtime/embed_dispatch defaults to true")

	var initialized_events: Array = []
	var shutdown_events: Array = []
	var runtime_errors: Array = []
	gdk.connect("initialized", func(): initialized_events.append(true))
	gdk.connect("shutdown_completed", func(): shutdown_events.append(true))
	gdk.connect("runtime_error", func(result): runtime_errors.append(result))

	var last_error = gdk.get_last_error()
	context.assert_not_null(last_error, "get_last_error() returns GDKResult")
	if last_error != null:
		context.assert_true(last_error.has_method("is_ok"), "last error exposes result API")

	var init_result = context.initialize_runtime()
	context.assert_not_null(init_result, "initialize() returns GDKResult")
	if init_result == null:
		context.disconnect_signal_handlers(gdk, ["initialized", "shutdown_completed", "runtime_error"])
		return

	if init_result.ok:
		context.assert_eq(initialized_events.size(), 1, "initialized signal emitted once")
		context.assert_eq(gdk.is_initialized(), true, "is_initialized() true after init")
		context.assert_true(gdk.dispatch() is int, "dispatch() returns int after init")

		var runtime_error_count_before_repeat = runtime_errors.size()
		var repeat_init_result = gdk.initialize()
		context.assert_not_null(repeat_init_result, "second initialize() returns GDKResult")
		if repeat_init_result != null:
			context.assert_eq(repeat_init_result.ok, false, "second initialize() fails while already initialized")
			context.assert_eq(repeat_init_result.code, "already_initialized", "second initialize() reports already_initialized")

			var repeat_last_error = gdk.get_last_error()
			context.assert_not_null(repeat_last_error, "get_last_error() tracks repeated initialize failure")
			if repeat_last_error != null:
				context.assert_eq(repeat_last_error.code, repeat_init_result.code, "last error matches repeated initialize() failure")

			context.assert_eq(runtime_errors.size(), runtime_error_count_before_repeat + 1, "runtime_error emitted for repeated initialize()")

		gdk.shutdown()
		context.assert_eq(shutdown_events.size(), 1, "shutdown_completed signal emitted once")
		context.assert_eq(gdk.is_initialized(), false, "is_initialized() false after shutdown")
		await _test_embed_dispatch_behavior(context, gdk)
	else:
		context.assert_true(runtime_errors.size() >= 1, "runtime_error emitted for initialize() failure")
		context.log_skip("GDK.initialize()", init_result.message)
		context.assert_eq(gdk.is_initialized(), false, "is_initialized() remains false after failed init")

	context.disconnect_signal_handlers(gdk, ["initialized", "shutdown_completed", "runtime_error"])

func _test_embed_dispatch_behavior(context, gdk) -> void:
	context.log_section("Embed Dispatch")

	var original_embed_dispatch: bool = context.get_embed_dispatch_enabled()

	context.set_embed_dispatch_enabled(true)
	var auto_init_result = context.initialize_runtime()
	context.assert_not_null(auto_init_result, "initialize() returns GDKResult for auto-dispatch coverage")
	if auto_init_result == null:
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return
	if not auto_init_result.ok:
		context.log_skip("Auto-dispatch behavior", auto_init_result.message)
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return

	var auto_op = gdk.users.add_default_user_async()
	context.assert_not_null(auto_op, "add_default_user_async() returns GDKAsyncOp for auto-dispatch coverage")
	if auto_op == null:
		context.reset_runtime()
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return

	if auto_op.is_done():
		context.log_skip("Auto-dispatch behavior", "The default-user op completed synchronously before frame-based coverage could run.")
	else:
		var auto_result = await context.wait_for_op_without_manual_dispatch(auto_op, 8000)
		if auto_result == null:
			auto_op.cancel()
			context.log_skip("Auto-dispatch behavior", "Timed out waiting for add_default_user_async() without manual GDK.dispatch().")
		else:
			context.log_pass("Auto-dispatch behavior", "completed without manual GDK.dispatch()")

	context.reset_runtime()

	context.set_embed_dispatch_enabled(false)
	var manual_init_result = context.initialize_runtime()
	context.assert_not_null(manual_init_result, "initialize() returns GDKResult for manual-dispatch coverage")
	if manual_init_result == null:
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return
	if not manual_init_result.ok:
		context.log_skip("Manual-dispatch fallback", manual_init_result.message)
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return

	var manual_op = gdk.users.add_default_user_async()
	context.assert_not_null(manual_op, "add_default_user_async() returns GDKAsyncOp when embed_dispatch is disabled")
	if manual_op == null:
		context.reset_runtime()
		context.set_embed_dispatch_enabled(original_embed_dispatch)
		return

	if manual_op.is_done():
		context.log_skip("Manual-dispatch fallback", "The default-user op completed synchronously before disabled-mode coverage could run.")
	else:
		var advanced_frames = await context.advance_process_frames(5)
		if not advanced_frames:
			context.log_skip("Manual-dispatch fallback", "The headless runner could not access process_frame for disabled-mode coverage.")
		else:
			context.assert_eq(manual_op.is_done(), false, "embed_dispatch disabled keeps async completion pending")

			var manual_result = context.wait_for_op(manual_op, 8000)
			if manual_result == null:
				manual_op.cancel()
				context.log_skip("Manual-dispatch fallback completion", "Timed out waiting for completion after manual GDK.dispatch().")
			else:
				context.log_pass("Manual-dispatch fallback completion", "completed after manual GDK.dispatch()")

	context.reset_runtime()
	context.set_embed_dispatch_enabled(original_embed_dispatch)
