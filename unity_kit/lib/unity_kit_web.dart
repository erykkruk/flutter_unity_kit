import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/utils/constants.dart';

/// Web (WebGL) implementation of the unity_kit platform plugin.
///
/// Registers the `com.unity_kit/unity_view` platform view as an
/// `HTMLDivElement` host and bridges Flutter <-> Unity over the per-view
/// [MethodChannel] that the shared Dart layer already uses on mobile. The
/// channel is bound to the plugin [BinaryMessenger] so app commands and
/// Unity callbacks flow in opposite directions without clashing.
///
/// ## Hosting the Unity WebGL build
///
/// The app ships the Unity WebGL output and exposes a global loader matching
/// Unity's generated `createUnityInstance`:
///
/// ```js
/// // web/index.html
/// window.unityKitCreateInstance = (canvas, config) =>
///   createUnityInstance(canvas, config);
/// ```
///
/// Unity reports back to Flutter through `window.unityKitSendToFlutter(json)`,
/// which this plugin installs automatically.
class UnityKitWeb {
  UnityKitWeb._();

  static final Map<int, _UnityWebView> _views = {};
  static BinaryMessenger? _messenger;
  static bool _globalCallbackInstalled = false;

  /// Registers this plugin with the Flutter web engine.
  static void registerWith(Registrar registrar) {
    _messenger = registrar;

    ui_web.platformViewRegistry.registerViewFactory(
      'com.unity_kit/unity_view',
      (int viewId, {Object? params}) => _createView(viewId, params).hostElement,
    );

    _installGlobalCallback();
  }

  static _UnityWebView _createView(int viewId, Object? params) {
    final config =
        params is Map ? Map<String, dynamic>.from(params) : <String, dynamic>{};

    final channel = MethodChannel(
      ChannelNames.methodChannel(viewId),
      const StandardMethodCodec(),
      _messenger,
    );

    final view =
        _UnityWebView(viewId: viewId, channel: channel, config: config);
    _views[viewId] = view;

    channel.setMethodCallHandler(view.handleCall);
    view.boot();

    return view;
  }

  static void _installGlobalCallback() {
    if (_globalCallbackInstalled) return;
    _globalCallbackInstalled = true;

    // Unity -> Flutter: fan a JSON string out to every active view's channel.
    globalContext.setProperty(
      'unityKitSendToFlutter'.toJS,
      (JSString json) {
        final payload = json.toDart;
        for (final view in _views.values) {
          view.dispatchFromUnity(payload);
        }
      }.toJS,
    );
  }
}

class _UnityWebView {
  _UnityWebView({
    required this.viewId,
    required this.channel,
    required this.config,
  }) : hostElement = (web.document.createElement('div') as web.HTMLDivElement)
          ..id = 'unity-kit-view-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';

  final int viewId;
  final MethodChannel channel;
  final Map<String, dynamic> config;
  final web.HTMLDivElement hostElement;

  web.HTMLCanvasElement? _canvas;
  JSObject? _unityInstance;
  bool _ready = false;

  void boot() {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    _canvas = canvas;
    hostElement.append(canvas);

    if (!globalContext.has('unityKitCreateInstance')) {
      _emitError('window.unityKitCreateInstance is not defined. Ship a Unity '
          'WebGL build and expose the loader (see UnityKitWeb docs).');
      return;
    }

    final loader =
        globalContext.getProperty('unityKitCreateInstance'.toJS) as JSFunction;
    final result = loader.callAsFunction(null, canvas, config.jsify());

    if (result.isA<JSPromise>()) {
      (result as JSPromise).toDart.then((instance) {
        _unityInstance = instance as JSObject?;
        _ready = true;
        channel.invokeMethod<void>('onUnityCreated');
      }).catchError((Object error) {
        _emitError('Unity WebGL failed to load: $error');
      });
    }
  }

  Future<Object?> handleCall(MethodCall call) async {
    switch (call.method) {
      case 'unity#isReady':
      case 'unity#isLoaded':
        return _ready;
      case 'unity#isPaused':
        return false;
      case 'unity#postMessage':
        _postMessage(Map<String, dynamic>.from(call.arguments as Map));
        return null;
      case 'unity#pausePlayer':
        _invoke('SetPaused', '1');
        return null;
      case 'unity#resumePlayer':
        _invoke('SetPaused', '0');
        return null;
      case 'unity#unloadPlayer':
      case 'unity#quitPlayer':
      case 'unity#dispose':
        _quit();
        return null;
      default:
        return null;
    }
  }

  void _postMessage(Map<String, dynamic> args) {
    final instance = _unityInstance;
    if (instance == null) return;
    if (!instance.has('SendMessage')) return;

    final gameObject =
        args['gameObject'] as String? ?? UnityGameObjects.flutterBridge;
    final method = args['methodName'] as String? ?? UnityMethods.receiveMessage;
    final message = args['message'] as String? ?? '';

    (instance.getProperty('SendMessage'.toJS) as JSFunction).callAsFunction(
      instance,
      gameObject.toJS,
      method.toJS,
      message.toJS,
    );
  }

  void _invoke(String method, String value) =>
      _postMessage({'methodName': method, 'message': value});

  void _quit() {
    final instance = _unityInstance;
    if (instance != null && instance.has('Quit')) {
      (instance.getProperty('Quit'.toJS) as JSFunction)
          .callAsFunction(instance);
    }
    _unityInstance = null;
    _ready = false;
    _canvas?.remove();
    UnityKitWeb._views.remove(viewId);
  }

  void dispatchFromUnity(String json) {
    channel.invokeMethod<void>('onUnityMessage', json);
  }

  void _emitError(String message) {
    channel.invokeMethod<void>('onError', {
      'data': {'message': message},
    });
  }
}
