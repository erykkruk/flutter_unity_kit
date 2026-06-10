#include "unity_kit_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace unity_kit {

// Channel matching the default active view id used by the Dart layer.
constexpr char kChannelName[] = "com.unity_kit/unity_view_0";

void UnityKitPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<UnityKitPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

UnityKitPlugin::UnityKitPlugin() {}

UnityKitPlugin::~UnityKitPlugin() {}

void UnityKitPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "unity#isReady" || method == "unity#isLoaded" ||
      method == "unity#isPaused") {
    result->Success(flutter::EncodableValue(false));
  } else if (method == "unity#createPlayer") {
    result->Error("unsupported",
                  "Unity player embedding is not yet available on Windows.");
  } else if (method == "unity#postMessage" || method == "unity#pausePlayer" ||
             method == "unity#resumePlayer" || method == "unity#unloadPlayer" ||
             method == "unity#quitPlayer" || method == "unity#dispose") {
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace unity_kit
