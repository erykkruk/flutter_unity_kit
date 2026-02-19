/// Constants for Flutter -> Unity method calls.
abstract final class UnityMethods {
  static const String loadScene = 'LoadScene';
  static const String unloadScene = 'UnloadScene';
  static const String setConfig = 'SetConfig';
  static const String triggerAction = 'TriggerAction';
  static const String queryState = 'QueryState';
  static const String receiveMessage = 'ReceiveMessage';
  static const String pause = 'Pause';
  static const String resume = 'Resume';
  static const String quit = 'Quit';
}

/// Constants for Unity -> Flutter signal types.
abstract final class UnitySignals {
  static const String ready = 'ready';
  static const String sceneLoaded = 'scene_loaded';
  static const String sceneUnloaded = 'scene_unloaded';
  static const String stateUpdate = 'state_update';
  static const String error = 'error';
  static const String paused = 'paused';
  static const String resumed = 'resumed';
  static const String destroyed = 'destroyed';
}

/// Default Unity GameObject names.
abstract final class UnityGameObjects {
  static const String flutterBridge = 'FlutterBridge';
}

/// MethodChannel and EventChannel name generators.
abstract final class ChannelNames {
  /// Returns the MethodChannel name for a specific view.
  static String methodChannel(int viewId) => 'com.unity_kit/unity_view_$viewId';

  /// The EventChannel name for Unity events.
  static const String eventChannel = 'com.unity_kit/unity_events';
}
