#ifndef PLAYFAB_SERVICES_H
#define PLAYFAB_SERVICES_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <PlayFabServiceConfig.h>
#include "pch.h"
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class PlayFabServices : public Object {
    GDCLASS(PlayFabServices, Object);

    static PlayFabServices *singleton;

    bool m_initialized = false;
    String m_title_id;
    String m_endpoint;
    PlayFabServiceConfig m_service_config_handle;

protected:
    static void _bind_methods();

public:
    static PlayFabServices *get_singleton();

    PlayFabServices();
    ~PlayFabServices();

    int initialize(const String &p_title_id);
    void shutdown();
    bool is_initialized() const;

    String get_title_id() const;
    String get_endpoint() const;
    PlayFabServiceConfig PlayFabServices::get_service_config() const;
};

} // namespace godot

#endif // PLAYFAB_SERVICES_H
