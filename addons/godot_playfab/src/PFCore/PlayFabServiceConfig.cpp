#include "PlayFabServiceConfig.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <playfab/core/PFServiceConfig.h>

#include <godot_cpp/core/print_string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

PlayFabServiceConfig::PlayFabServiceConfig() {

}

PlayFabServiceConfig::~PlayFabServiceConfig() {
    close_handle();
}

int PlayFabServiceConfig::create_handle(const String &p_api_endpoint, const String &p_title_id) {
    close_handle();

    std::string endpoint_std = p_api_endpoint.utf8().get_data();
    std::string title_id_std = p_title_id.utf8().get_data();

    HRESULT hr = PFServiceConfigCreateHandle(endpoint_std.c_str(), title_id_std.c_str(), &m_handle);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServiceConfig: PFServiceConfigCreateHandle failed with HRESULT 0x", String::num_int64(hr, 16));
        return 0;
    }

    UtilityFunctions::print("PlayFabServiceConfig: handle created for title ", p_title_id);
    return 1;
}

void PlayFabServiceConfig::close_handle() {
    if (m_handle != nullptr) {
        PFServiceConfigCloseHandle(m_handle);
        m_handle = nullptr;
    }
}

String PlayFabServiceConfig::get_api_endpoint() const {
    if (m_handle == nullptr) {
        UtilityFunctions::printerr("PlayFabServiceConfig: handle is null");
        return String();
    }

    size_t size = 0;
    HRESULT hr = PFServiceConfigGetAPIEndpointSize(m_handle, &size);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServiceConfig: PFServiceConfigGetAPIEndpointSize failed with HRESULT 0x", String::num_int64(hr, 16));
        return String();
    }

    std::vector<char> buffer(size);
    hr = PFServiceConfigGetAPIEndpoint(m_handle, size, buffer.data(), nullptr);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServiceConfig: PFServiceConfigGetAPIEndpoint failed with HRESULT 0x", String::num_int64(hr, 16));
        return String();
    }

    return String(buffer.data());
}

String PlayFabServiceConfig::get_title_id() const {
    if (m_handle == nullptr) {
        UtilityFunctions::printerr("PlayFabServiceConfig: handle is null");
        return String();
    }

    size_t size = 0;
    HRESULT hr = PFServiceConfigGetTitleIdSize(m_handle, &size);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServiceConfig: PFServiceConfigGetTitleIdSize failed with HRESULT 0x", String::num_int64(hr, 16));
        return String();
    }

    std::vector<char> buffer(size);
    hr = PFServiceConfigGetTitleId(m_handle, size, buffer.data(), nullptr);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("PlayFabServiceConfig: PFServiceConfigGetTitleId failed with HRESULT 0x", String::num_int64(hr, 16));
        return String();
    }

    return String(buffer.data());
}

bool PlayFabServiceConfig::is_valid() const {
    return m_handle != nullptr;
}

PFServiceConfigHandle PlayFabServiceConfig::get_handle() const {
    return m_handle;
}

} // namespace godot
