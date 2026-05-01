#ifndef PLAYFAB_AUTHENTICATION_H
#define PLAYFAB_AUTHENTICATION_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "pch.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/variant/variant.hpp>
#include "PlayFabServiceConfig.h"
#include "EntityHandle.h"

namespace godot {

class PlayFabAuthentication{

    EntityHandle* m_entity_handle;

public:

    PlayFabAuthentication();
    ~PlayFabAuthentication();

    int login_with_custom_id(const String &p_custom_id, bool p_create_account, PlayFabServiceConfig handle);
    int login_with_xuser(int64_t p_xuser_handle, bool p_create_account, PlayFabServiceConfig handle);
    void close_entity_handle();
};

} // namespace godot

#endif // PLAYFAB_AUTHENTICATION_H
