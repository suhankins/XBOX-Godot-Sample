#include "PlayFabServices.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <playfab/services/PFServices.h>

#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

PlayFabServices *PlayFabServices::singleton = nullptr;

PlayFabServices *PlayFabServices::get_singleton() {
    return singleton;
}

PlayFabServices::PlayFabServices() {
    ERR_FAIL_COND(singleton != nullptr);
    singleton = this;
}

PlayFabServices::~PlayFabServices() {
    shutdown();
    singleton = nullptr;
}

void PlayFabServices::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "title_id"), &PlayFabServices::initialize);
    ClassDB::bind_method(D_METHOD("shutdown"), &PlayFabServices::shutdown);
    ClassDB::bind_method(D_METHOD("is_initialized"), &PlayFabServices::is_initialized);
    ClassDB::bind_method(D_METHOD("get_title_id"), &PlayFabServices::get_title_id);
    ClassDB::bind_method(D_METHOD("get_endpoint"), &PlayFabServices::get_endpoint);

    ADD_SIGNAL(MethodInfo("initialized"));
    ADD_SIGNAL(MethodInfo("shutdown_completed"));
}

int PlayFabServices::initialize(const String &p_title_id) {
    if (m_initialized) {
        UtilityFunctions::printerr("PlayFabServices: already initialized");
        return 0;
    }

    if (p_title_id.is_empty()) {
        UtilityFunctions::printerr("PlayFabServices: title_id must not be empty");
        return 0;
    }

    m_title_id = p_title_id;
    m_endpoint = "https://" + m_title_id + ".playfabapi.com";

    HRESULT hr = PFServicesInitialize(nullptr);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServices: PFServicesInitialize failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    int result = m_service_config_handle.create_handle(m_endpoint, m_title_id);

    if (!result) {
        UtilityFunctions::printerr("PlayFabServices: PFServiceConfigCreateHandle failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    m_initialized = true;
    emit_signal("initialized");
    UtilityFunctions::print("PlayFabServices: initialized for title ", m_title_id);
    return 1;
}


void PlayFabServices::shutdown() {
    if (!m_initialized) {
        return;
    }

    if (m_service_config_handle.is_valid()) {
        m_service_config_handle.close_handle();
    }

    XAsyncBlock async = {};
    HRESULT hr = PFServicesUninitializeAsync(&async);
    if (SUCCEEDED(hr)) {
        XAsyncGetStatus(&async, true);
    }

    m_initialized = false;
    emit_signal("shutdown_completed");
    UtilityFunctions::print("PlayFabServices: shut down");
}

bool PlayFabServices::is_initialized() const {
    return m_initialized;
}

String PlayFabServices::get_title_id() const {
    return m_title_id;
}

String PlayFabServices::get_endpoint() const {
    return m_endpoint;
}

PlayFabServiceConfig PlayFabServices::get_service_config() const{
    return m_service_config_handle;
}

} // namespace godot