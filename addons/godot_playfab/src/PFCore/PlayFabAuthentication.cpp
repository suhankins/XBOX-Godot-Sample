#include "PlayFabAuthentication.h"
#include "PlayFabServiceConfig.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <playfab/core/PFAuthentication.h>
#include <playfab/core/PFAuthenticationTypes.h>
#include <playfab/core/PFEntity.h>

#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

PlayFabAuthentication::PlayFabAuthentication() {
    m_entity_handle = nullptr;
}

PlayFabAuthentication::~PlayFabAuthentication() {
    if (m_entity_handle != nullptr) {
        delete m_entity_handle;
        m_entity_handle = nullptr;
    }
}

int PlayFabAuthentication::login_with_custom_id(const String &p_custom_id, bool p_create_account, PlayFabServiceConfig handle) {
    PlayFabServiceConfig svc_config = handle;
    if (!svc_config.is_valid()) {
        UtilityFunctions::printerr("PlayFabAuthentication: PlayFabServiceConfig handle is not valid");
        return 0;
    }

    std::string custom_id_std = p_custom_id.utf8().get_data();

    PFAuthenticationLoginWithCustomIDRequest request = {};
    request.createAccount = p_create_account;
    request.customId = custom_id_std.c_str();

    XAsyncBlock async = {};
    HRESULT hr = PFAuthenticationLoginWithCustomIDAsync(svc_config.get_handle(), &request, &async);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: PFAuthenticationLoginWithCustomIDAsync failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    hr = XAsyncGetStatus(&async, true);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: XAsyncGetStatus failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    size_t buffer_size = 0;
    hr = PFAuthenticationLoginWithCustomIDGetResultSize(&async, &buffer_size);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: GetResultSize failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    std::vector<char> buffer(buffer_size);
    PFAuthenticationLoginResult const *login_result = nullptr;
    PFEntityHandle raw_entity = nullptr;

    hr = PFAuthenticationLoginWithCustomIDGetResult(&async, &raw_entity, buffer_size, buffer.data(), &login_result, nullptr);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: GetResult failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    close_entity_handle();
    m_entity_handle->set_handle(raw_entity, true);

    UtilityFunctions::print("PlayFabAuthentication: login_with_custom_id succeeded");
    return 1;
}

int PlayFabAuthentication::login_with_xuser(int64_t p_xuser_handle, bool p_create_account, PlayFabServiceConfig handle) {
#if HC_PLATFORM == HC_PLATFORM_GDK
    PlayFabServiceConfig svc_config = handle;
    if (!svc_config.is_valid()) {
        UtilityFunctions::printerr("PlayFabAuthentication: PlayFabServiceConfig handle is not valid");
        return 0;
    }

    PFAuthenticationLoginWithXUserRequest request = {};
    request.createAccount = p_create_account;
    request.user = reinterpret_cast<XUserHandle>(p_xuser_handle);

    XAsyncBlock async = {};
    HRESULT hr = PFAuthenticationLoginWithXUserAsync(svc_config.get_handle(), &request, &async);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: PFAuthenticationLoginWithXUserAsync failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    hr = XAsyncGetStatus(&async, true);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: XAsyncGetStatus failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    size_t buffer_size = 0;
    hr = PFAuthenticationLoginWithXUserGetResultSize(&async, &buffer_size);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: GetResultSize failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    std::vector<char> buffer(buffer_size);
    PFAuthenticationLoginResult const *login_result = nullptr;
    PFEntityHandle raw_entity = nullptr;

    hr = PFAuthenticationLoginWithXUserGetResult(&async, &raw_entity, buffer_size, buffer.data(), &login_result, nullptr);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabAuthentication: GetResult failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    close_entity_handle();
    m_entity_handle->set_handle(raw_entity, true);

    UtilityFunctions::print("PlayFabAuthentication: login_with_xuser succeeded");
    return 1;
#else
    UtilityFunctions::printerr("PlayFabAuthentication: login_with_xuser is only available on GDK");
    return 0;
#endif
}

void PlayFabAuthentication::close_entity_handle() {
    if (m_entity_handle != nullptr) {
        m_entity_handle->close_handle();
    }
}

} // namespace godot
