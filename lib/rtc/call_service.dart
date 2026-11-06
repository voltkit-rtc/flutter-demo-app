import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android foreground service that keeps a room or call alive in the background: LiveCallService.kt. Android cuts
/// off an app's network and microphone within seconds of leaving the screen without one. Its notification opens the
/// app and has a Leave action. iOS uses the audio background mode instead, so there is nothing to start.
class CallService {
  CallService._();

  static const _channel = MethodChannel('voltkit_live/call_service');
  static VoidCallback? _onLeave;

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Calling this again updates the notification, and takes the microphone type once the permission is there.
  static Future<void> start({required String title, required String text, required String leaveLabel, required VoidCallback onLeave}) async {
    if (!_android) return;
    _onLeave = onLeave;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'leave') _onLeave?.call();
    });
    try {
      await _channel.invokeMethod<void>('start', {'title': title, 'text': text, 'leaveLabel': leaveLabel});
    } on PlatformException {
      // The room still works while the app is open.
    }
  }

  static Future<void> stop() async {
    if (!_android) return;
    _onLeave = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Nothing was running.
    }
  }
}
