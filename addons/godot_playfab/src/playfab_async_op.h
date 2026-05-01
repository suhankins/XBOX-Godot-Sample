#ifndef GODOT_PLAYFAB_ASYNC_OP_H
#define GODOT_PLAYFAB_ASYNC_OP_H

#include <functional>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "playfab_result.h"

namespace godot {

class PlayFabAsyncOp : public RefCounted {
    GDCLASS(PlayFabAsyncOp, RefCounted);

    bool m_done = false;
    bool m_cancel_requested = false;
    Ref<PlayFabResult> m_result;
    std::function<void()> m_cancel_handler;
    std::function<void(PlayFabAsyncOp *)> m_release_handler;

protected:
    static void _bind_methods();
    bool request_cancel();
    void invoke_cancel_handler();

public:
    bool is_done() const;
    virtual bool cancel();
    Ref<PlayFabResult> get_result() const;

    bool was_cancel_requested() const;
    void complete(const Ref<PlayFabResult> &p_result);
    void set_cancel_handler(std::function<void()> p_handler);
    void clear_cancel_handler();
    void set_release_handler(std::function<void(PlayFabAsyncOp *)> p_handler);
    void clear_release_handler();
};

} // namespace godot

#endif // GODOT_PLAYFAB_ASYNC_OP_H
