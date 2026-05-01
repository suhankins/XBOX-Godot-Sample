#ifndef GODOT_PLAYFAB_RUNTIME_H
#define GODOT_PLAYFAB_RUNTIME_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <vector>

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <XGameRuntimeInit.h>
#include <XTaskQueue.h>
#include <playfab/core/PFCore.h>
#include <playfab/gamesave/PFGameSaveFiles.h>
#include <playfab/services/PFServices.h>

namespace godot {

class PlayFabAsyncOp;
class PlayFabResult;

class PlayFabRuntime {
    bool m_initialized = false;
    bool m_shutting_down = false;
    bool m_game_save_files_initialized = false;
    XTaskQueueHandle m_task_queue = nullptr;
    PFServiceConfigHandle m_service_config_handle = nullptr;
    String m_title_id;
    String m_endpoint;
    std::vector<Ref<PlayFabAsyncOp>> m_active_ops;
    Ref<PlayFabResult> m_last_error;

    static void CALLBACK _queue_terminated(void *p_context);

public:
    PlayFabRuntime();
    ~PlayFabRuntime();

    Ref<PlayFabResult> initialize();
    void shutdown();
    int dispatch();

    bool is_initialized() const;
    bool is_shutting_down() const;
    bool is_available() const;
    XTaskQueueHandle get_task_queue() const;
    PFServiceConfigHandle get_service_config_handle() const;
    String get_title_id() const;
    String get_endpoint() const;

    void retain_op(const Ref<PlayFabAsyncOp> &p_op);
    void release_op(PlayFabAsyncOp *p_op);
    Ref<PlayFabAsyncOp> make_completed_async_op(const Ref<PlayFabResult> &p_result);
    Ref<PlayFabAsyncOp> make_error_async_op(HRESULT p_hresult, const String &p_code, const String &p_message, const Variant &p_data = Variant());

    Ref<PlayFabResult> get_last_error() const;
    void set_last_error(const Ref<PlayFabResult> &p_result);
    void clear_last_error();
};

} // namespace godot

#endif // GODOT_PLAYFAB_RUNTIME_H
