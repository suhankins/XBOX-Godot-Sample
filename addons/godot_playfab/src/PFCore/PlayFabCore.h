#ifndef PLAYFAB_CORE_H
#define PLAYFAB_CORE_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "pch.h"
#include <PlayFabAuthentication.h>
#include <PlayFabServiceConfig.h>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class PlayFabCore : public Object {
    GDCLASS(PlayFabCore, Object);

    static PlayFabCore *singleton;
	PFServiceConfigHandle m_serviceHandle{ nullptr };
    PlayFabAuthentication *m_playFabAuthentication = nullptr;
    bool m_initialized = false;
protected:
    static void _bind_methods();

public:
    static PlayFabCore *get_singleton();

    PlayFabCore();
    ~PlayFabCore();

    int initialize();
    void shutdown();
    bool is_initialized() const;
    int login_with_custom_id(const String& p_custom_id);
    int login_with_xuser(const int p_custom_id);
};

} // namespace godot

#endif // PLAYFAB_CORE_H
