#ifndef FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

/// C-style registration entry point called by the generated plugin registrant.
///
/// Takes a C-style FlutterDesktopPluginRegistrarRef and delegates to the
/// class-based RegisterWithRegistrar inside the flutter_music_picker namespace.
FLUTTER_PLUGIN_EXPORT void FlutterMusicPickerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_C_API_H_
