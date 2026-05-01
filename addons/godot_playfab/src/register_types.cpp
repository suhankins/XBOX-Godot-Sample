#include "register_types.h"
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/godot.hpp>

#include <PFCore/PlayFabCore.h>
#include <PFCore/PlayFabServiceConfig.h>
#include <PFCore/PlayFabAuthentication.h>
#include <PlayFabServices.h>
#include <EntityHandle.h>
#include <PartyImpl.h>

using namespace godot;

static PlayFabCore *playfabCore_singleton = nullptr;
static PlayFabServices *playfabServices_singleton = nullptr;

void initialize_gdextension_types(ModuleInitializationLevel p_level)
{
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
	}
	GDREGISTER_RUNTIME_CLASS(PlayFabCore);
	GDREGISTER_RUNTIME_CLASS(PlayFabServices);

	playfabCore_singleton = memnew(PlayFabCore);
	Engine::get_singleton()->register_singleton("PlayFabCore", PlayFabCore::get_singleton());

	playfabServices_singleton = memnew(PlayFabServices);
	Engine::get_singleton()->register_singleton("PlayFabServices", PlayFabServices::get_singleton());

}

void uninitialize_gdextension_types(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
	}
	Engine::get_singleton()->unregister_singleton("PlayFabCore");
	if (playfabCore_singleton) {
		memdelete(playfabCore_singleton);
		playfabCore_singleton = nullptr;
	}
	Engine::get_singleton()->unregister_singleton("PlayFabServices");
	if (playfabServices_singleton) {
		memdelete(playfabServices_singleton);
		playfabServices_singleton = nullptr;
	}
}

extern "C"
{
	// Initialization
	GDExtensionBool GDE_EXPORT godot_playfab_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
	{
		GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
		init_obj.register_initializer(initialize_gdextension_types);
		init_obj.register_terminator(uninitialize_gdextension_types);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

		return init_obj.init();
	}
}