#ifndef GODOT_PLAYFAB_XASYNC_CONTEXT_H
#define GODOT_PLAYFAB_XASYNC_CONTEXT_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <XAsync.h>

#include "playfab_async_op.h"

namespace godot {

class PlayFabRuntime;

class PlayFabXAsyncContext {
    XAsyncBlock m_async_block = {};

    static void CALLBACK _completion_thunk(XAsyncBlock *p_async_block);

protected:
    PlayFabRuntime *m_runtime = nullptr;
    Ref<PlayFabAsyncOp> m_op;

    virtual void finalize(XAsyncBlock *p_async_block) = 0;

public:
    PlayFabXAsyncContext(PlayFabRuntime *p_runtime, const Ref<PlayFabAsyncOp> &p_op);
    virtual ~PlayFabXAsyncContext() = default;

    XAsyncBlock *get_async_block();
    PlayFabRuntime *get_runtime() const;
    Ref<PlayFabAsyncOp> get_op() const;
    void bind_cancel_handler();
    void clear_cancel_handler();
};

} // namespace godot

#endif // GODOT_PLAYFAB_XASYNC_CONTEXT_H
