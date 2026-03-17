extends Node
## Autoload script that initializes GDK at startup and manages lifecycle.

func _ready() -> void:
	print("=== GodotGDK Bootstrap ===")
	print("GDK Version: ", GDK.get_version())

	# Connect signals
	GDK.connect("initialized", _on_gdk_initialized)
	GDK.connect("error_occurred", _on_gdk_error)
	GDKUser.connect("user_signed_in", _on_user_signed_in)
	GDKUser.connect("sign_in_failed", _on_sign_in_failed)
	GDKUser.connect("user_signed_out", _on_user_signed_out)
	GDKInput.connect("device_connected", _on_device_connected)
	GDKInput.connect("device_disconnected", _on_device_disconnected)

	# Initialize GDK runtime
	var err = GDK.initialize()
	if err != OK:
		push_error("GDK initialization failed: %s" % error_string(err))

func _on_gdk_initialized() -> void:
	print("[GDK] Runtime initialized!")

	# Initialize GameInput
	var err = GDKInput.initialize()
	if err == OK:
		print("[GDK] GameInput ready, devices: ", GDKInput.get_connected_device_count())

	# Try silent sign-in
	GDKUser.sign_in_silently()

func _on_gdk_error(message: String) -> void:
	push_error("[GDK] Error: " + message)

func _on_user_signed_in(user) -> void:
	print("[GDK] User signed in successfully")

func _on_sign_in_failed(error: String) -> void:
	push_warning("[GDK] Sign-in failed: " + error)

func _on_user_signed_out() -> void:
	print("[GDK] User signed out")

func _on_device_connected(joy_id: int) -> void:
	print("[GDK] Controller connected: joy ", joy_id)

func _on_device_disconnected(joy_id: int) -> void:
	print("[GDK] Controller disconnected: joy ", joy_id)

func _process(delta: float) -> void:
	# Dispatch GDK async callbacks
	GDK.tick()

	# Poll GameInput
	GDKInput.process()

func _exit_tree() -> void:
	GDKInput.shutdown()
	GDK.shutdown()
	print("[GDK] Shut down cleanly")
