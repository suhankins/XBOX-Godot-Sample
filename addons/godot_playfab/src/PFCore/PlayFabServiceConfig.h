#ifndef PLAYFAB_SERVICE_CONFIG_H
#define PLAYFAB_SERVICE_CONFIG_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "pch.h"
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class PlayFabServiceConfig {

    PFServiceConfigHandle m_handle = nullptr;

public:
    PlayFabServiceConfig();
    ~PlayFabServiceConfig();

    int create_handle(const String &p_api_endpoint, const String &p_title_id);
    void close_handle();
    String get_api_endpoint() const;
    String get_title_id() const;
    bool is_valid() const;

    PFServiceConfigHandle get_handle() const;
};

} // namespace godot

#endif // PLAYFAB_SERVICE_CONFIG_H
