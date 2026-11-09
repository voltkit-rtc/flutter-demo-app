import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../config.dart';
import '../util/toast.dart';

const _channel = MethodChannel('voltkit_live/call_service');

/// The last value the SDK recorded for [event] in its diagnostics log, such as `echoSuppression` (which echo suppression
/// it chose on this phone, and why) or `phoneEchoCanceller` (what the phone's own canceller is).
String? _latest(Diagnostics d, String event) {
  for (final e in d.log.reversed) {
    if (e.event == event) return e.detail is String ? e.detail as String : jsonEncode(e.detail);
  }
  return null;
}

/// Copies what VoltKit asks for when someone reports an echo or other sound trouble: the phone, its Android version,
/// where the sound plays and how loud, the SDK's echo choices, and its whole diagnostics snapshot. The person then pastes
/// it into a message, with a few words about what they heard.
Future<void> copySoundReport(StreamClient client, {required bool loudspeaker}) async {
  try {
    final d = await client.getDiagnostics();
    Map<Object?, Object?> phone = const {};
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        phone = await _channel.invokeMethod<Map<Object?, Object?>>('device') ?? const {};
      } on PlatformException {
        // The report still has the SDK's side.
      }
    }
    final volume = phone['callVolume'] != null ? '${phone['callVolume']} of ${phone['callVolumeMax']}' : 'unknown';
    final lines = [
      '${Voltkit.appName} sound report',
      'Phone: ${phone['manufacturer'] ?? '?'} ${phone['model'] ?? '?'}, Android ${phone['android'] ?? '?'} (API ${phone['sdk'] ?? '?'})',
      'Sound from: ${phone['route'] ?? 'unknown'} (the app asked for the ${loudspeaker ? 'loudspeaker' : 'earpiece'}), call volume $volume',
      'SDK: voltkit_rtc $sdkVersion',
      'echoCanceller: ${_latest(d, 'echoCanceller') ?? 'not recorded'}',
      'echoSuppression: ${_latest(d, 'echoSuppression') ?? 'not recorded'}',
      'phoneEchoCanceller: ${_latest(d, 'phoneEchoCanceller') ?? 'not recorded'}',
      '',
      'Diagnostics:',
      const JsonEncoder.withIndent('  ').convert(d.toJson()),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    toast('Sound report copied. Paste it in a message to VoltKit, with what you heard.', ToastKind.success);
  } catch (_) {
    toast('Could not make the sound report.', ToastKind.error);
  }
}
