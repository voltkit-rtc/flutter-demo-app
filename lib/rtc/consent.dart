import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/ui.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/toast.dart';

const _key = 'media-consent-v1';

/// Set on the app's Navigator, so a screen can ask without holding a context of its own.
final navigatorKey = GlobalKey<NavigatorState>();

/// Nothing goes on air without this: the app explains what happens once, then the system asks. Viewers are never
/// asked, because they publish nothing.
Future<bool> askMediaConsent(RoomType type) async {
  if (await Session.storage.read(key: _key) == null) {
    final yes = await _explain(type);
    if (!yes) return false;
    await Session.storage.write(key: _key, value: '1');
  }

  final kinds = <String, Permission>{
    if (type == 'video') 'camera': Permission.camera,
    'microphone': Permission.microphone,
  };
  final statuses = await kinds.values.toList().request();
  // Only so the call's notification shows. The call works without it.
  await Permission.notification.request();

  final refused = [
    for (final entry in kinds.entries)
      if (statuses[entry.value]?.isGranted != true) entry.key,
  ];
  if (refused.isEmpty) return true;
  if (kinds.entries.any((e) => statuses[e.value]?.isPermanentlyDenied == true)) {
    toast('Allow the ${refused.join(' and ')} in Settings to go on air.', ToastKind.error);
    await openAppSettings();
  } else {
    toast('The ${refused.join(' and ')} ${refused.length > 1 ? 'are' : 'is'} needed to go on air.', ToastKind.error);
  }
  return false;
}

Future<bool> _explain(RoomType type) async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;
  return await showSheet<bool>(context, id: 'consent-sheet', builder: (context) => _ConsentSheet(type: type)) ?? false;
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({required this.type});

  final RoomType type;

  @override
  Widget build(BuildContext context) {
    final video = type == 'video';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(video ? Ion.videocam : Ion.mic, size: 38, color: C.magenta),
          const SizedBox(height: 10),
          const T('Going on air', variant: V.title, align: TextAlign.center),
          const SizedBox(height: 10),
          T(
            'Everyone in the room or call sees and hears you live. Your ${video ? 'camera and microphone are' : 'microphone is'} only '
            'on while you are on stage, and you can switch ${video ? 'them' : 'it'} off at any time. This app does not record you.',
            color: C.textDim,
            align: TextAlign.center,
          ),
          const SizedBox(height: 18),
          GradientButton(id: 'consent-accept', label: 'I understand', onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 10),
          GhostButton(label: 'Not now', onTap: () => Navigator.pop(context, false)),
        ],
      ),
    );
  }
}
