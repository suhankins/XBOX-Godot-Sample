extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _run_playfab() -> void:
	# print($PlayFabManager.RunPlayFabSDKSample())
	var pf_core = _get_pfcore()
	var pf_services = _get_pfservices()
	
	if pf_core == null:
		push_warning("[GDK] Extension not loaded")
	pf_core.initialize()
	
	if pf_services == null:
		push_warning("[GDK] Extension not loaded")
	
	var titleid = "99DA"
	pf_services.initialize(titleid)
	
	var is_initialize = pf_core.is_initialized()
	
	if !is_initialize:
		push_warning("not initialized")
	
	var customid = "SampleLoginCustomId"
	var result = pf_core.login_with_custom_id(customid)
	if result == 0:
		push_warning("Login Failed")
	pf_services.shutdown()
	pf_core.shutdown()
	
	pass

func _get_pfcore():
	if Engine.has_singleton("PlayFabCore"):
		return Engine.get_singleton("PlayFabCore")
	return null
	
func _get_pfservices():
	if Engine.has_singleton("PlayFabServices"):
		return Engine.get_singleton("PlayFabServices")
	return null
