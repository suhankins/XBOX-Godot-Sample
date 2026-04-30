#ifndef ENTITY_HANDLE_H
#define ENTITY_HANDLE_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "pch.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class EntityHandle {

    static PFEntityHandle m_handle;
    static bool m_owns_handle;

public:
    EntityHandle();
    ~EntityHandle();

    int set_handle(PFEntityHandle p_handle, bool p_owns);
    PFEntityHandle get_handle();

    int close_handle();

    String get_entity_token();
    Dictionary get_entity_key();
    bool is_title_player();
    String get_api_endpoint();
    String get_title_id();
    bool is_valid() const;
};

} // namespace godot

#endif // ENTITY_HANDLE_H
