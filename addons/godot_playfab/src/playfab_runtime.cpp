#include "playfab_runtime.h"

#include <algorithm>

#include <godot_cpp/classes/project_settings.hpp>

#include "playfab_async_op.h"
#include "playfab_result.h"

namespace godot {

namespace {

#if defined(HC_PLATFORM) && HC_PLATFORM == HC_PLATFORM_GDK
constexpr bool PLAYFAB_GDK_PLATFORM = true;
#else
constexpr bool PLAYFAB_GDK_PLATFORM = false;
#endif

void wait_for_async_completion(HRESULT p_start_hr, XAsyncBlock *p_async_block) {
    if (SUCCEEDED(p_start_hr)) {
        XAsyncGetStatus(p_async_block, true);
    }
}

constexpr const char *PLAYFAB_TITLE_ID_SETTING = "playfab/titleid";
constexpr const char *PLAYFAB_ENDPOINT_SETTING = "playfab/endpoint";

} // namespace

PlayFabRuntime::PlayFabRuntime() {
    clear_last_error();
}

PlayFabRuntime::~PlayFabRuntime() {
    shutdown();
}

Ref<PlayFabResult> PlayFabRuntime::initialize() {
    if (m_initialized) {
        Ref<PlayFabResult> result = PlayFabResult::error_result(E_FAIL, "already_initialized", "PlayFab runtime is already initialized.");
        set_last_error(result);
        return result;
    }

    if (!PLAYFAB_GDK_PLATFORM) {
        Ref<PlayFabResult> result = PlayFabResult::error_result(E_FAIL, "platform_unsupported", "The refactored PlayFab runtime currently supports GDK platforms only.");
        set_last_error(result);
        return result;
    }

    ProjectSettings *project_settings = ProjectSettings::get_singleton();
    if (project_settings == nullptr) {
        Ref<PlayFabResult> result = PlayFabResult::error_result(E_FAIL, "project_settings_unavailable", "ProjectSettings is unavailable.");
        set_last_error(result);
        return result;
    }

    const String title_id = String(project_settings->get_setting(PLAYFAB_TITLE_ID_SETTING, "")).strip_edges();
    String endpoint = String(project_settings->get_setting(PLAYFAB_ENDPOINT_SETTING, "")).strip_edges();
    if (title_id.is_empty()) {
        Ref<PlayFabResult> result = PlayFabResult::error_result(E_INVALIDARG, "title_id_required", "PlayFab initialization requires ProjectSettings['playfab/titleid'] to be set.");
        set_last_error(result);
        return result;
    }

    if (endpoint.is_empty()) {
        endpoint = "https://" + title_id + ".playfabapi.com";
    }

    bool xgame_runtime_initialized = false;
    bool playfab_core_initialized = false;
    bool playfab_services_initialized = false;
    bool game_save_files_initialized = false;

    HRESULT hr = XGameRuntimeInitialize();
    if (FAILED(hr)) {
        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to initialize the Gaming Runtime.", "runtime_initialize_failed");
        set_last_error(result);
        return result;
    }
    xgame_runtime_initialized = true;

    hr = XTaskQueueCreate(
            XTaskQueueDispatchMode::ThreadPool,
            XTaskQueueDispatchMode::Manual,
            &m_task_queue);
    if (FAILED(hr)) {
        XGameRuntimeUninitialize();

        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to create the shared XTaskQueue.", "task_queue_create_failed");
        set_last_error(result);
        return result;
    }

    hr = PFInitialize(nullptr);
    if (FAILED(hr)) {
        XTaskQueueCloseHandle(m_task_queue);
        m_task_queue = nullptr;
        XGameRuntimeUninitialize();

        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to initialize PlayFab Core.", "playfab_core_initialize_failed");
        set_last_error(result);
        return result;
    }
    playfab_core_initialized = true;

    hr = PFServicesInitialize(nullptr);
    if (FAILED(hr)) {
        XAsyncBlock async = {};
        wait_for_async_completion(PFUninitializeAsync(&async), &async);

        XTaskQueueCloseHandle(m_task_queue);
        m_task_queue = nullptr;
        XGameRuntimeUninitialize();

        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to initialize PlayFab Services.", "playfab_services_initialize_failed");
        set_last_error(result);
        return result;
    }
    playfab_services_initialized = true;

    PFGameSaveInitArgs game_save_init_args = {};
    game_save_init_args.backgroundQueue = m_task_queue;
    game_save_init_args.options = static_cast<uint64_t>(PFGameSaveInitOptions::None);
    game_save_init_args.saveFolder = nullptr;

    hr = PFGameSaveFilesInitialize(&game_save_init_args);
    if (FAILED(hr)) {
        if (playfab_services_initialized) {
            XAsyncBlock services_async = {};
            wait_for_async_completion(PFServicesUninitializeAsync(&services_async), &services_async);
        }
        if (playfab_core_initialized) {
            XAsyncBlock core_async = {};
            wait_for_async_completion(PFUninitializeAsync(&core_async), &core_async);
        }

        XTaskQueueCloseHandle(m_task_queue);
        m_task_queue = nullptr;
        XGameRuntimeUninitialize();

        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to initialize PlayFab Game Save Files.", "playfab_gamesave_initialize_failed");
        set_last_error(result);
        return result;
    }
    game_save_files_initialized = true;

    m_title_id = title_id;
    m_endpoint = endpoint;

    const CharString endpoint_utf8 = m_endpoint.utf8();
    const CharString title_id_utf8 = m_title_id.utf8();
    hr = PFServiceConfigCreateHandle(
            endpoint_utf8.get_data(),
            title_id_utf8.get_data(),
            &m_service_config_handle);
    if (FAILED(hr)) {
        if (game_save_files_initialized) {
            XAsyncBlock game_save_async = {};
            wait_for_async_completion(PFGameSaveFilesUninitializeAsync(&game_save_async), &game_save_async);
        }
        if (playfab_services_initialized) {
            XAsyncBlock services_async = {};
            wait_for_async_completion(PFServicesUninitializeAsync(&services_async), &services_async);
        }
        if (playfab_core_initialized) {
            XAsyncBlock core_async = {};
            wait_for_async_completion(PFUninitializeAsync(&core_async), &core_async);
        }

        XTaskQueueCloseHandle(m_task_queue);
        m_task_queue = nullptr;
        m_title_id = "";
        m_endpoint = "";
        if (xgame_runtime_initialized) {
            XGameRuntimeUninitialize();
        }

        Ref<PlayFabResult> result = PlayFabResult::hresult_error(hr, "Failed to create the PlayFab service configuration.", "service_config_create_failed");
        set_last_error(result);
        return result;
    }

    m_initialized = true;
    m_shutting_down = false;
    m_game_save_files_initialized = true;
    clear_last_error();
    return PlayFabResult::ok_result();
}

void PlayFabRuntime::shutdown() {
    if (!m_initialized) {
        return;
    }

    m_shutting_down = true;

    std::vector<Ref<PlayFabAsyncOp>> active_ops = m_active_ops;
    for (const Ref<PlayFabAsyncOp> &op : active_ops) {
        if (op.is_valid()) {
            op->cancel();
        }
    }

    if (m_game_save_files_initialized) {
        XAsyncBlock game_save_async = {};
        wait_for_async_completion(PFGameSaveFilesUninitializeAsync(&game_save_async), &game_save_async);
        m_game_save_files_initialized = false;
    }

    if (m_service_config_handle != nullptr) {
        PFServiceConfigCloseHandle(m_service_config_handle);
        m_service_config_handle = nullptr;
    }

    XAsyncBlock services_async = {};
    wait_for_async_completion(PFServicesUninitializeAsync(&services_async), &services_async);

    XAsyncBlock core_async = {};
    wait_for_async_completion(PFUninitializeAsync(&core_async), &core_async);

    if (m_task_queue != nullptr) {
        bool terminated = false;
        HRESULT terminate_hr = XTaskQueueTerminate(m_task_queue, false, &terminated, _queue_terminated);
        if (SUCCEEDED(terminate_hr)) {
            while (!terminated) {
                XTaskQueueDispatch(m_task_queue, XTaskQueuePort::Completion, 10);
            }
        }

        XTaskQueueCloseHandle(m_task_queue);
        m_task_queue = nullptr;
    }

    for (Ref<PlayFabAsyncOp> &op : m_active_ops) {
        if (op.is_valid()) {
            op->clear_cancel_handler();
            op->clear_release_handler();
        }
    }
    m_active_ops.clear();

    XGameRuntimeUninitialize();

    m_initialized = false;
    m_shutting_down = false;
    m_game_save_files_initialized = false;
    m_title_id = "";
    m_endpoint = "";
    clear_last_error();
}

int PlayFabRuntime::dispatch() {
    if (!m_initialized || m_task_queue == nullptr) {
        return 0;
    }

    int dispatched = 0;
    while (XTaskQueueDispatch(m_task_queue, XTaskQueuePort::Completion, 0)) {
        ++dispatched;
    }

    return dispatched;
}

bool PlayFabRuntime::is_initialized() const {
    return m_initialized;
}

bool PlayFabRuntime::is_shutting_down() const {
    return m_shutting_down;
}

bool PlayFabRuntime::is_available() const {
    return PLAYFAB_GDK_PLATFORM;
}

XTaskQueueHandle PlayFabRuntime::get_task_queue() const {
    return m_task_queue;
}

PFServiceConfigHandle PlayFabRuntime::get_service_config_handle() const {
    return m_service_config_handle;
}

String PlayFabRuntime::get_title_id() const {
    return m_title_id;
}

String PlayFabRuntime::get_endpoint() const {
    return m_endpoint;
}

void PlayFabRuntime::retain_op(const Ref<PlayFabAsyncOp> &p_op) {
    if (!p_op.is_valid() || p_op->is_done()) {
        return;
    }

    p_op->set_release_handler([this](PlayFabAsyncOp *p_completed_op) {
        release_op(p_completed_op);
    });
    m_active_ops.push_back(p_op);
}

void PlayFabRuntime::release_op(PlayFabAsyncOp *p_op) {
    m_active_ops.erase(
            std::remove_if(
                    m_active_ops.begin(),
                    m_active_ops.end(),
                    [p_op](const Ref<PlayFabAsyncOp> &candidate) {
                        return candidate.is_null() || candidate.operator->() == p_op;
                    }),
            m_active_ops.end());
}

Ref<PlayFabAsyncOp> PlayFabRuntime::make_completed_async_op(const Ref<PlayFabResult> &p_result) {
    Ref<PlayFabAsyncOp> op;
    op.instantiate();
    op->complete(p_result);
    return op;
}

Ref<PlayFabAsyncOp> PlayFabRuntime::make_error_async_op(HRESULT p_hresult, const String &p_code, const String &p_message, const Variant &p_data) {
    Ref<PlayFabResult> result = PlayFabResult::error_result(p_hresult, p_code, p_message, p_data);
    set_last_error(result);
    return make_completed_async_op(result);
}

Ref<PlayFabResult> PlayFabRuntime::get_last_error() const {
    return m_last_error;
}

void PlayFabRuntime::set_last_error(const Ref<PlayFabResult> &p_result) {
    m_last_error = p_result;
}

void PlayFabRuntime::clear_last_error() {
    m_last_error = PlayFabResult::ok_result();
}

void CALLBACK PlayFabRuntime::_queue_terminated(void *p_context) {
    bool *terminated = static_cast<bool *>(p_context);
    if (terminated != nullptr) {
        *terminated = true;
    }
}

} // namespace godot
