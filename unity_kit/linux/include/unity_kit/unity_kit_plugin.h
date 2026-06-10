#ifndef FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_
#define FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void unity_kit_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_
