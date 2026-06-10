#include "include/unity_kit/unity_kit_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "unity_kit_plugin.h"

void UnityKitPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  unity_kit::UnityKitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
