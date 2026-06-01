# Plugin-level CMake configuration for flutter_music_picker on Windows.
# Builds the plugin C++ source into a shared library that the Flutter
# engine loads at runtime via the plugin registry.
cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "flutter_music_picker")
project(${PROJECT_NAME} LANGUAGES CXX)

# This plugin builds a shared library
set(PLUGIN_NAME "flutter_music_picker_plugin")

# Plugin source files — both the main class and the C API wrapper
add_library(${PLUGIN_NAME} SHARED
  "flutter_music_picker_plugin.h"
  "flutter_music_picker_plugin.cpp"
  "flutter_music_picker/flutter_music_picker_plugin_c_api.h"
  "flutter_music_picker/flutter_music_picker_plugin_c_api.cpp"
)

# Apply standard Flutter compilation settings
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# INTERFACE include makes the current dir available to consuming targets.
# The generated registrant uses #include <flutter_music_picker/...>
# which resolves to <CMAKE_CURRENT_SOURCE_DIR>/flutter_music_picker/...
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}")

# Tell MSVC to interpret source files as UTF-8, avoiding C4819 errors
# on Chinese Windows where the default code page is 936 (GBK).
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8)
endif()

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Bundled libraries (none for this plugin)
set(flutter_music_picker_bundled_libraries
  ""
  CACHE STRING "Bundled libraries for flutter_music_picker plugin." FORCE
)
