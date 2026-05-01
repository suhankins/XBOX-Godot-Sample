#include "playfab_xasync_context.h"

#include "playfab_runtime.h"

namespace godot {

PlayFabXAsyncContext::PlayFabXAsyncContext(PlayFabRuntime *p_runtime, const Ref<PlayFabAsyncOp> &p_op) :
        m_runtime(p_runtime),
        m_op(p_op) {
    m_async_block.queue = m_runtime != nullptr ? m_runtime->get_task_queue() : nullptr;
    m_async_block.context = this;
    m_async_block.callback = _completion_thunk;
}

XAsyncBlock *PlayFabXAsyncContext::get_async_block() {
    return &m_async_block;
}

PlayFabRuntime *PlayFabXAsyncContext::get_runtime() const {
    return m_runtime;
}

Ref<PlayFabAsyncOp> PlayFabXAsyncContext::get_op() const {
    return m_op;
}

void PlayFabXAsyncContext::bind_cancel_handler() {
    if (m_op.is_valid()) {
        m_op->set_cancel_handler([this]() {
            XAsyncCancel(&m_async_block);
        });
    }
}

void PlayFabXAsyncContext::clear_cancel_handler() {
    if (m_op.is_valid()) {
        m_op->clear_cancel_handler();
    }
}

void CALLBACK PlayFabXAsyncContext::_completion_thunk(XAsyncBlock *p_async_block) {
    auto *context = static_cast<PlayFabXAsyncContext *>(p_async_block->context);

    context->clear_cancel_handler();
    context->finalize(p_async_block);
    delete context;
}

} // namespace godot
