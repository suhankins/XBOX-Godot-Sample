#ifndef GODOT_GAMEINPUT_EXTENSION_H
#define GODOT_GAMEINPUT_EXTENSION_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class GodotGameInputExtension : public Object {
    GDCLASS(GodotGameInputExtension, Object);

protected:
    static void _bind_methods();
};

} // namespace godot

#endif // GODOT_GAMEINPUT_EXTENSION_H
