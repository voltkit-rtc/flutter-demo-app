import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:http/http.dart' as http;
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../app_assets.dart';
import '../components/ui.dart';
import '../config.dart';
import '../theme.dart';
import 'queue.dart';

/// Gets the catalog's animations on disk before the first gift, so nothing has to wait for a download.
Future<void> preloadGifts(List<String> urls) async {
  for (final url in urls.map(assetUrl)) {
    try {
      if (await SVGACache.shared.getRawBytes(url) != null) continue;
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) await SVGACache.shared.putRawBytes(url, res.bodyBytes);
    } catch (_) {
      // A file that did not arrive is fetched when it is played, or falls back to its icon.
    }
  }
}

class _Fallback extends StatefulWidget {
  const _Fallback({super.key, required this.icon, required this.onDone});

  final String icon;
  final VoidCallback onDone;

  @override
  State<_Fallback> createState() => _FallbackState();
}

class _FallbackState extends State<_Fallback> with SingleTickerProviderStateMixin {
  late final _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), reverseDuration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _p.animateTo(1, curve: Curves.elasticOut).orCancel;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _p.reverse().orCancel;
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: AnimatedBuilder(
          animation: _p,
          builder: (context, child) => Opacity(opacity: _p.value.clamp(0, 1), child: Transform.scale(scale: _p.value, child: child)),
          child: Asset(giftIconAsset(widget.icon), width: 200, height: 200, fit: BoxFit.contain),
        ),
      );
}

class _Banner extends StatefulWidget {
  const _Banner({super.key, required this.item});

  final GiftItem item;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _x = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();
  late final _eased = CurvedAnimation(parent: _x, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _eased.dispose();
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedBuilder(
      animation: _eased,
      builder: (context, child) => Opacity(
        opacity: _eased.value,
        child: Transform.translate(offset: Offset(-220 * (1 - _eased.value), 0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.pill),
          gradient: const LinearGradient(colors: [Color(0xF28B5CF6), Color(0xD1EC4899)]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(item.fromName, variant: V.small, lines: 1),
                  T('sent ${item.giftName} to ${item.toName}', variant: V.tiny, lines: 1, color: C.gold),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Asset(giftIconAsset(item.icon), width: 34, height: 34, fit: BoxFit.contain),
            if (item.count > 1) ...[const SizedBox(width: 8), T('×${item.count}', variant: V.heading, color: C.gold)],
          ],
        ),
      ),
    );
  }
}

class _EntranceName extends StatelessWidget {
  const _EntranceName({required this.name, required this.frame});

  final String name;
  final String frame;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(avatar: null, frame: frame == 'none' ? 'lion' : frame, size: 40),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: textStyle(V.heading).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
          ),
          const SizedBox(height: 2),
          const T('has arrived', variant: V.tiny, color: C.gold),
        ],
      );
}

/// Plays gifts and entrances one at a time over the room. Everything arrives as a VoltKit chat message sent by the
/// backend. A file that cannot be played falls back to the gift's icon, and a stall skips ahead, so a bad animation
/// can never hold up the queue.
class GiftStage extends StatefulWidget {
  const GiftStage({super.key, required this.client});

  final StreamClient client;

  @override
  State<GiftStage> createState() => _GiftStageState();
}

class _GiftStageState extends State<GiftStage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _queue = GiftQueue();
  late final _player = SVGAAnimationController(vsync: this, muted: true);
  late final StreamSubscription<ChatMessage> _sub;
  StageItem? _item;
  var _failed = false;
  var _loaded = false;
  var _play = 0;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _sub = widget.client.onMessage.listen(_onMessage);
  }

  void _onMessage(ChatMessage m) {
    final meta = m.metadata ?? const {};
    final url = meta['svgaUrl'];
    if (url is! String || url.isEmpty) return;
    if (m.type == 'gift') {
      _add(GiftItem(
        id: m.id,
        url: assetUrl(url),
        icon: meta['icon'] as String? ?? meta['giftId'] as String? ?? 'heart',
        fromName: meta['fromName'] as String? ?? 'Someone',
        toName: meta['toName'] as String? ?? 'the host',
        giftName: meta['giftName'] as String? ?? 'a gift',
        count: (meta['count'] as num?)?.toInt() ?? 1,
        tier: meta['tier'] as String? ?? 'basic',
      ));
    } else if (m.type == 'entrance') {
      _add(EntranceItem(id: m.id, url: assetUrl(url), name: meta['name'] as String? ?? 'Guest', frame: meta['frame'] as String? ?? 'none'));
    }
  }

  void _add(StageItem entry) {
    _queue.push(entry);
    if (_item == null) _next();
  }

  void _next() {
    _watchdog?.cancel();
    if (!mounted) return;
    final item = _queue.next();
    _play++;
    if (_player.isAnimating) _player.stop();
    _player.videoItem = null;
    setState(() {
      _item = item;
      _failed = false;
      _loaded = false;
    });
    if (item == null) return;
    // The player can stall, and then its end never comes.
    _watchdog = Timer(const Duration(seconds: 9), _next);
    unawaited(_load(item, _play));
  }

  Future<void> _load(StageItem item, int play) async {
    try {
      final movie = await SVGAParser.shared.decodeFromURL(item.url);
      if (!mounted || play != _play) {
        movie.dispose();
        return;
      }
      _player.videoItem = movie;
      setState(() => _loaded = true);
      unawaited(_player.forward(from: 0));
    } catch (err) {
      debugPrint('svga failed: $err');
      if (!mounted || play != _play) return;
      if (item is GiftItem) {
        setState(() => _failed = true);
      } else {
        _next();
      }
    }
  }

  // The player stops in the background, so anything queued is stale by the time the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) return;
    _queue.clear();
    if (_item != null) _next();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    _watchdog?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final movie = SVGAImage(_player, fit: BoxFit.contain, clearsAfterStop: true);
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Semantics(
            identifier: 'gift-stage',
            child: Stack(
              children: [
                switch (item) {
                  GiftItem() => _failed
                      ? _Fallback(key: ValueKey(item.id), icon: item.icon, onDone: _next)
                      : Center(child: SizedBox.square(dimension: size.width, child: _loaded ? movie : null)),
                  EntranceItem() => Positioned(
                      left: 0,
                      right: 0,
                      top: size.height * 0.30,
                      child: SizedBox(width: size.width, height: size.width * 320 / 750, child: _loaded ? movie : null),
                    ),
                },
                switch (item) {
                  GiftItem() => Positioned(
                      left: 10,
                      top: size.height * 0.42,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: size.width * 0.76),
                        child: _Banner(key: ValueKey('b${item.id}'), item: item),
                      ),
                    ),
                  EntranceItem() => Positioned(
                      left: 0,
                      right: 0,
                      top: size.height * 0.37,
                      child: _EntranceName(name: item.name, frame: item.frame),
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
