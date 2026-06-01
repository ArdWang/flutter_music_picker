# Plugin-level CMake configuration for flutter_music_picker on Linux.
# Builds the plugin C++ source into a shared library (.so) that the
# Flutter engine loads at runtime.
cmake_minimum_required(VERSION 3.13)
set(PROJECT_NAME "flutter_music_picker")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "flutter_music_picker_plugin")

# Plugin source files
add_library(${PLUGIN_NAME} SHARED
  "flutter_music_picker_plugin.cc"
  "flutter_music_picker_plugin.h"
)

# Apply standard Flutter compilation settings for Linux plugins
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter_linux_plugin PkgConfig::GTK)

set(flutter_music_picker_bundled_libraries
  ""
  CACHE STRING "Bundled libraries for flutter_music_picker plugin." FORCE
)
