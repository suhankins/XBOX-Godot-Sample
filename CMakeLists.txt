cmake_minimum_required(VERSION 3.20)
project(godot_gdk LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Godot-cpp
add_subdirectory(godot-cpp)

# GDK paths
set(GDK_ROOT "C:/Program Files (x86)/Microsoft GDK" CACHE PATH "Microsoft GDK install root")

# Find the latest GDK edition
file(GLOB GDK_EDITIONS "${GDK_ROOT}/[0-9]*")
list(SORT GDK_EDITIONS ORDER DESCENDING)
list(GET GDK_EDITIONS 0 GDK_EDITION_PATH)
message(STATUS "Using GDK edition: ${GDK_EDITION_PATH}")

set(GDK_GAMEKIT "${GDK_EDITION_PATH}/GRDK/GameKit")
set(GDK_EXTENSIONS "${GDK_EDITION_PATH}/GRDK/ExtensionLibraries")

# Our plugin library
add_library(godot_gdk SHARED
    src/register_types.cpp
    src/gdk_core.cpp
    src/gdk_user.cpp
    src/gdk_input.cpp
)

target_include_directories(godot_gdk PRIVATE
    src/
    "${GDK_GAMEKIT}/Include"
)

target_link_directories(godot_gdk PRIVATE
    ${GDK_GAMEKIT}/Lib/amd64
)

target_link_libraries(godot_gdk PRIVATE
    godot::cpp
    xgameruntime
    GameInput
)

# GameInput is a system COM interface, no extra lib needed beyond xgameruntime
# Extension libraries (Xbox Services etc) will be added in later milestones

# Output to both addon bin directories
set(ADDON_BIN "${CMAKE_SOURCE_DIR}/addons/godot_gdk/bin")
set(SAMPLE_BIN "${CMAKE_SOURCE_DIR}/sample/addons/godot_gdk/bin")

set_target_properties(godot_gdk PROPERTIES
    OUTPUT_NAME "godot_gdk.windows.release.x86_64"
    RUNTIME_OUTPUT_DIRECTORY "${ADDON_BIN}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${ADDON_BIN}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${ADDON_BIN}"
    LIBRARY_OUTPUT_DIRECTORY "${ADDON_BIN}"
    LIBRARY_OUTPUT_DIRECTORY_DEBUG "${ADDON_BIN}"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${ADDON_BIN}"
    PREFIX ""
    SUFFIX ".dll"
)

# Copy to sample project after build
add_custom_command(TARGET godot_gdk POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:godot_gdk>"
        "${SAMPLE_BIN}/$<TARGET_FILE_NAME:godot_gdk>"
    COMMENT "Copying DLL to sample project"
)

# Debug variant
set_target_properties(godot_gdk PROPERTIES
    OUTPUT_NAME_DEBUG "godot_gdk.windows.debug.x86_64"
)
