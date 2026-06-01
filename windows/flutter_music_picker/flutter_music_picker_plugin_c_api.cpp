#include "flutter_music_picker_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "../flutter_music_picker_plugin.h"

/// C-style registration entry point for the Flutter plugin system.
///
/// Converts the C-style FlutterDesktopPluginRegistrarRef into a
/// flutter::PluginRegistrarWindows* and delegates to the class-based
/// RegisterWithRegistrar method.
void FlutterMusicPickerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_music_picker::FlutterMusicPickerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
