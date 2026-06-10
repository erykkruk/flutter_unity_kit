#ifndef FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_
#define FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace unity_kit {

// Windows implementation of the unity_kit plugin.
//
// Desktop Unity-as-a-library embedding is a work in progress, so the plugin
// answers lifecycle/query calls with safe defaults. This keeps the Dart API
// usable and lets apps build on Windows without MissingPluginException.
class UnityKitPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  UnityKitPlugin();
  ~UnityKitPlugin() override;

  UnityKitPlugin(const UnityKitPlugin&) = delete;
  UnityKitPlugin& operator=(const UnityKitPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace unity_kit

#endif  // FLUTTER_PLUGIN_UNITY_KIT_PLUGIN_H_
