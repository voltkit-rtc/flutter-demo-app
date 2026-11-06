import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../config.dart';
import '../icons.dart';
import '../theme.dart';
import '../types.dart';

const _features = [
  (Ion.videocam, 'Video rooms', 'Host and co-host cards with adaptive video, up to 1080p'),
  (Ion.mic, 'Audio rooms', 'Seats kept by the server, with live speaking indicators'),
  (Ion.shuffle, '1v1 calls', 'Face-to-face video that reconnects on its own'),
  (Ion.shieldCheckmark, 'Roles and moderation', 'Host, co-host, moderator and viewer, enforced by the service'),
  (Ion.chatbubbles, 'Realtime chat', 'In every room, in the lounge and in direct messages'),
  (Ion.sparkles, 'SVGA gifts', 'Animated gifts and entrance effects, sent through chat'),
];

String _rupees(String value) {
  final n = num.tryParse(value);
  if (n == null) return value;
  return n == n.toInt() ? '${n.toInt()}' : '$n';
}

class VoltKitScreen extends StatefulWidget {
  const VoltKitScreen({super.key});

  @override
  State<VoltKitScreen> createState() => _VoltKitScreenState();
}

class _VoltKitScreenState extends State<VoltKitScreen> {
  Rates? _rates;

  @override
  void initState() {
    super.initState();
    api.rates().then((r) {
      if (mounted) setState(() => _rates = r);
    }, onError: (Object _) {});
  }

  Widget _price(String label, String value) => Expanded(
        child: Panel(
          child: Column(
            children: [
              T(label, variant: V.small, color: C.textDim),
              T('₹${_rupees(value)}', variant: V.display, color: C.gold),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final rates = _rates;
    return Scaffold(
      body: Backdrop(
        colors: G.launch,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, insets.top + 8, 16, insets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: gapped(14, [
              Align(alignment: Alignment.centerLeft, child: IconBtn(size: 40, icon: Ion.chevronBack, label: 'Back', onTap: () => Navigator.of(context).pop())),
              Column(
                children: gapped(6, const [
                  Asset(Art.mark, width: 84, height: 84, fit: BoxFit.contain),
                  Wordmark(size: 40),
                  T(Voltkit.tagline, variant: V.heading, color: C.gold, align: TextAlign.center),
                  T('${Voltkit.build}.', color: C.textDim, align: TextAlign.center),
                  SizedBox(height: 6),
                  BuiltWith(),
                ]),
              ),
              const Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(Voltkit.demoLine, variant: V.small, color: C.gold),
                    SizedBox(height: 4),
                    T(
                      'This app is built with Flutter, and everything live in it runs on VoltKit RTC. Want the same experience in your own app? Start with an API key and the Flutter SDK.',
                      color: C.textDim,
                    ),
                  ],
                ),
              ),
              Column(
                children: gapped(8, [
                  for (final (icon, title, text) in _features)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(R.md)),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: diagonal(G.video)),
                            child: Icon(icon, size: 19, color: C.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                T(title, variant: V.medium),
                                T(text, variant: V.small, color: C.textDim),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),
              ),
              if (rates?.audio != null && rates?.video != null) ...[
                Row(
                  children: [_price('Audio from', rates!.audio!), const SizedBox(width: 10), _price('Video', rates.video!)],
                ),
                T(rates.unit, variant: V.tiny, color: C.textFaint, align: TextAlign.center),
              ],
              GradientButton(id: 'voltkit-site', label: 'Build this into your app', icon: Ion.arrowForward, dark: true, colors: G.gold, onTap: () => unawaited(openUrl(Voltkit.flutterPage))),
              GhostButton(label: 'Go to voltkit.in', icon: Ion.globeOutline, onTap: () => unawaited(openUrl(Voltkit.site))),
              GhostButton(label: 'Flutter SDK docs', icon: Icons.flutter_dash, onTap: () => unawaited(openUrl(Voltkit.flutterDocs))),
            ]),
          ),
        ),
      ),
    );
  }
}
