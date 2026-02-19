import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const String _kDefaultScene = 'MainScene';

// Parameter names sent to Unity
const String _kParamRotationX = 'rotationX';
const String _kParamRotationY = 'rotationY';
const String _kParamRotationZ = 'rotationZ';
const String _kParamScale = 'scale';
const String _kParamSpeed = 'speed';
const String _kParamIntensity = 'intensity';
const String _kParamPositionX = 'positionX';
const String _kParamPositionY = 'positionY';

// Gesture sensitivity multipliers
const double _kRotationSensitivity = 0.5;
const double _kPositionSensitivity = 0.01;
const double _kScaleMin = 0.1;
const double _kScaleMax = 5.0;

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

void main() {
  runApp(const UnityKitExampleApp());
}

class UnityKitExampleApp extends StatelessWidget {
  const UnityKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unity Kit Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main screen -- Unity view + sliders
// ---------------------------------------------------------------------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _unityReady = false;
  UnityBridge? _bridge;

  // Gesture-controlled values
  double _rotationX = 0;
  double _rotationY = 0;
  double _positionX = 0;
  double _positionY = 0;
  double _scale = 1.0;
  double _baseScale = 1.0;

  // Slider-controlled values
  double _speed = 1.0;
  double _intensity = 0.5;

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_unityReady) return;

    setState(() {
      if (details.pointerCount == 1) {
        // Single finger drag = rotation
        _rotationY += details.focalPointDelta.dx * _kRotationSensitivity;
        _rotationX -= details.focalPointDelta.dy * _kRotationSensitivity;
      } else if (details.pointerCount >= 2) {
        // Two fingers: pinch = scale, pan = position
        _scale = (_baseScale * details.scale).clamp(_kScaleMin, _kScaleMax);
        _positionX += details.focalPointDelta.dx * _kPositionSensitivity;
        _positionY -= details.focalPointDelta.dy * _kPositionSensitivity;
      }
    });

    _sendTransform();
  }

  void _sendTransform() {
    final bridge = _bridge;
    if (bridge == null) return;

    final params = {
      _kParamRotationX: _rotationX,
      _kParamRotationY: _rotationY,
      _kParamScale: _scale,
      _kParamPositionX: _positionX,
      _kParamPositionY: _positionY,
    };

    for (final entry in params.entries) {
      bridge.sendWhenReady(
        UnityMessage.command('SetParameter', {
          'param': entry.key,
          'value': entry.value,
        }),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Slider change handlers
  // ---------------------------------------------------------------------------

  void _onSliderChanged(String param, double value) {
    _bridge?.sendWhenReady(
      UnityMessage.command('SetParameter', {
        'param': param,
        'value': value,
      }),
    );
  }

  void _onSpeedChanged(double value) {
    setState(() => _speed = value);
    _onSliderChanged(_kParamSpeed, value);
  }

  void _onIntensityChanged(double value) {
    setState(() => _intensity = value);
    _onSliderChanged(_kParamIntensity, value);
  }

  void _resetAll() {
    setState(() {
      _rotationX = 0;
      _rotationY = 0;
      _positionX = 0;
      _positionY = 0;
      _scale = 1.0;
      _baseScale = 1.0;
      _speed = 1.0;
      _intensity = 0.5;
    });

    _bridge?.sendWhenReady(
      UnityMessage.command('ResetParameters', {}),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Unity Kit'),
        backgroundColor: Colors.transparent,
        actions: [
          _StatusChip(isReady: _unityReady),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset all',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Unity view with gesture detection
          Expanded(child: _buildUnityArea()),

          // Gesture info + remaining sliders
          _ControlsPanel(
            rotationX: _rotationX,
            rotationY: _rotationY,
            positionX: _positionX,
            positionY: _positionY,
            scale: _scale,
            speed: _speed,
            intensity: _intensity,
            onSpeedChanged: _onSpeedChanged,
            onIntensityChanged: _onIntensityChanged,
            enabled: _unityReady,
          ),
        ],
      ),
    );
  }

  Widget _buildUnityArea() {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return const UnityPlaceholder(
        message: 'Unity view is not available on this platform.',
        backgroundColor: Colors.black,
        indicatorColor: Colors.deepPurple,
      );
    }

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: UnityView(
        config: const UnityConfig(
          sceneName: _kDefaultScene,
          fullscreen: false,
          platformViewMode: PlatformViewMode.hybridComposition,
          targetFrameRate: 60,
          unloadOnDispose: true,
        ),
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
        },
        placeholder: const UnityPlaceholder(
          message: 'Loading 3D view...',
          backgroundColor: Colors.black,
          indicatorColor: Colors.deepPurple,
        ),
        onReady: (bridge) {
          developer.log('UnityView ready', name: 'example');
          setState(() {
            _unityReady = true;
            _bridge = bridge;
          });
        },
        onMessage: (message) {
          developer.log(
            'Unity message: ${message.type} ${message.data ?? ''}',
            name: 'example',
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? Colors.green : Colors.orange;
    final label = isReady ? 'ready' : 'loading';
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Controls panel -- gesture readouts + remaining sliders
// ---------------------------------------------------------------------------

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.rotationX,
    required this.rotationY,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.speed,
    required this.intensity,
    required this.onSpeedChanged,
    required this.onIntensityChanged,
    required this.enabled,
  });

  final double rotationX;
  final double rotationY;
  final double positionX;
  final double positionY;
  final double scale;
  final double speed;
  final double intensity;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onIntensityChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Gesture readouts
              _GestureInfo(
                rotationX: rotationX,
                rotationY: rotationY,
                positionX: positionX,
                positionY: positionY,
                scale: scale,
              ),

              const SizedBox(height: 8),

              // Remaining sliders
              _SliderRow(
                label: 'Speed',
                value: speed,
                min: 0,
                max: 5.0,
                onChanged: enabled ? onSpeedChanged : null,
                valueLabel: '${speed.toStringAsFixed(1)}x',
              ),
              _SliderRow(
                label: 'Intensity',
                value: intensity,
                min: 0,
                max: 1.0,
                onChanged: enabled ? onIntensityChanged : null,
                valueLabel: '${(intensity * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gesture info readout
// ---------------------------------------------------------------------------

class _GestureInfo extends StatelessWidget {
  const _GestureInfo({
    required this.rotationX,
    required this.rotationY,
    required this.positionX,
    required this.positionY,
    required this.scale,
  });

  final double rotationX;
  final double rotationY;
  final double positionX;
  final double positionY;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 11,
      color: Colors.white38,
    );
    const valueStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'monospace',
      color: Colors.white60,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _InfoItem(
          label: 'Rot',
          value:
              '${rotationX.toStringAsFixed(0)}, ${rotationY.toStringAsFixed(0)}',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _InfoItem(
          label: 'Pos',
          value:
              '${positionX.toStringAsFixed(2)}, ${positionY.toStringAsFixed(2)}',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _InfoItem(
          label: 'Scale',
          value: '${scale.toStringAsFixed(2)}x',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 2),
        Text(value, style: valueStyle),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single slider row
// ---------------------------------------------------------------------------

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.valueLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onChanged != null ? Colors.white70 : Colors.white30,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.deepPurple[300],
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.deepPurple[200],
                disabledActiveTrackColor: Colors.grey[700],
                disabledInactiveTrackColor: Colors.grey[850],
                disabledThumbColor: Colors.grey[600],
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: onChanged != null ? Colors.white70 : Colors.white30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
