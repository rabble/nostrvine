#include "include/cryptography_flutter/cryptography_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// Stub Linux implementation of the cryptography_flutter plugin.
//
// The upstream package (2.3.2) only ships native code for Android, iOS, and
// macOS. We register the method channel here and respond `NotImplemented`
// to every call so the Dart side of `package:cryptography_flutter` falls
// back to its pure-Dart implementation via `package:cryptography`.
//
// Without this stub the engine logs "No implementation found for method ..."
// noise on Linux desktop startup. Replace with a real backend once the
// upstream package adds Linux support.

#define CRYPTOGRAPHY_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), cryptography_flutter_plugin_get_type(), \
                              CryptographyFlutterPlugin))

struct _CryptographyFlutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(CryptographyFlutterPlugin, cryptography_flutter_plugin, g_object_get_type())

static void cryptography_flutter_plugin_handle_method_call(
    CryptographyFlutterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  CryptographyFlutterPlugin* plugin = CRYPTOGRAPHY_FLUTTER_PLUGIN(user_data);
  cryptography_flutter_plugin_handle_method_call(plugin, method_call);
}

void cryptography_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  CryptographyFlutterPlugin* plugin = CRYPTOGRAPHY_FLUTTER_PLUGIN(
      g_object_new(cryptography_flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "cryptography_flutter",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}

static void cryptography_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(cryptography_flutter_plugin_parent_class)->dispose(object);
}

static void cryptography_flutter_plugin_class_init(CryptographyFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = cryptography_flutter_plugin_dispose;
}

static void cryptography_flutter_plugin_init(CryptographyFlutterPlugin* self) {}
