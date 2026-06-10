#include "include/unity_kit/unity_kit_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define UNITY_KIT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), unity_kit_plugin_get_type(), \
                              UnityKitPlugin))

// Channel matching the default active view id used by the Dart layer.
static const char kChannelName[] = "com.unity_kit/unity_view_0";

struct _UnityKitPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(UnityKitPlugin, unity_kit_plugin, g_object_get_type())

// Desktop Unity-as-a-library embedding is a work in progress. The plugin
// answers lifecycle/query calls with safe defaults so the Dart API stays
// usable and apps build on Linux without MissingPluginException.
static void unity_kit_plugin_handle_method_call(UnityKitPlugin* self,
                                                 FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "unity#isReady") == 0 ||
      strcmp(method, "unity#isLoaded") == 0 ||
      strcmp(method, "unity#isPaused") == 0) {
    g_autoptr(FlValue) value = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (strcmp(method, "unity#createPlayer") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "unsupported",
        "Unity player embedding is not yet available on Linux.", nullptr));
  } else if (strcmp(method, "unity#postMessage") == 0 ||
             strcmp(method, "unity#pausePlayer") == 0 ||
             strcmp(method, "unity#resumePlayer") == 0 ||
             strcmp(method, "unity#unloadPlayer") == 0 ||
             strcmp(method, "unity#quitPlayer") == 0 ||
             strcmp(method, "unity#dispose") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void unity_kit_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(unity_kit_plugin_parent_class)->dispose(object);
}

static void unity_kit_plugin_class_init(UnityKitPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = unity_kit_plugin_dispose;
}

static void unity_kit_plugin_init(UnityKitPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  UnityKitPlugin* plugin = UNITY_KIT_PLUGIN(user_data);
  unity_kit_plugin_handle_method_call(plugin, method_call);
}

void unity_kit_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  UnityKitPlugin* plugin = UNITY_KIT_PLUGIN(
      g_object_new(unity_kit_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
