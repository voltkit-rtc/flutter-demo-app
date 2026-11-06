import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/socket.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../config.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/routes.dart';
import 'create_screen.dart';
import 'match_screen.dart';
import 'room_screen.dart';
import 'tabs.dart';
import 'voltkit_screen.dart';

const _filters = [
  ('all', 'All live', Ion.flame),
  ('video', 'Video', Ion.videocam),
  ('audio', 'Audio', Ion.mic),
];

class _Equalizer extends StatefulWidget {
  const _Equalizer();

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with TickerProviderStateMixin {
  late final _bars = [
    for (var i = 0; i < 3; i++)
      AnimationController(
        vsync: this,
        lowerBound: 0.3,
        duration: Duration(milliseconds: 300 + i * 120),
        reverseDuration: Duration(milliseconds: 340 + i * 90),
      )..repeat(reverse: true),
  ];

  @override
  void dispose() {
    for (final b in _bars) {
      b.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox(
          height: 11,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: gapped(2, horizontal: true, [
              for (final b in _bars)
                ScaleTransition(
                  scale: b,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 2.5,
                    height: 11,
                    decoration: BoxDecoration(color: C.cyan, borderRadius: BorderRadius.circular(1)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({super.key, required this.room, required this.onTap});

  final Room room;
  final void Function(Room room) onTap;

  @override
  Widget build(BuildContext context) => Tap(
        id: 'room-card-${room.type}',
        label: '${room.type} room, ${room.title}, hosted by ${room.host.name}, ${room.viewers} people',
        onTap: () => onTap(room),
        pressedScale: 0.97,
        child: LayoutBuilder(
          builder: (context, box) => Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: C.plum,
              borderRadius: BorderRadius.circular(R.lg),
              border: Border.all(color: C.glassBorder, width: hairline(context)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Asset(coverAsset(room.theme), width: box.maxWidth, height: box.maxHeight),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.4, 1],
                      colors: [Color(0x59050309), Color(0x00050309), Color(0xF2050309)],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const LivePill(), TagChip(icon: Ion.people, label: compact(room.viewers))],
                      ),
                    ),
                    Center(child: Avatar(avatar: room.host.avatar, frame: room.host.frame, size: 58)),
                    Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(room.isVideo ? Ion.videocam : Ion.mic, size: 13, color: room.isVideo ? C.pink : C.cyan),
                              const SizedBox(width: 5),
                              if (!room.isVideo) ...[const _Equalizer(), const SizedBox(width: 5)],
                              T(room.isVideo ? 'Video room' : 'Audio room', variant: V.tiny, color: C.textDim),
                            ],
                          ),
                          const SizedBox(height: 3),
                          T(room.title, variant: V.heading, lines: 1),
                          const SizedBox(height: 1),
                          T(room.host.name, variant: V.small, lines: 1, color: C.textDim),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.hint, required this.tint, required this.onTap, required this.id});

  final IconData icon;
  final String title;
  final String hint;
  final List<Color> tint;
  final VoidCallback onTap;
  final String id;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Tap(
          id: id,
          label: title,
          onTap: onTap,
          pressedScale: 0.97,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.glass,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: C.glassBorder, width: hairline(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: diagonal(tint)),
                  child: Icon(icon, size: 22, color: C.white),
                ),
                T(title, variant: V.small, lines: 1),
                const SizedBox(height: 3),
                T(hint, variant: V.tiny, lines: 1, color: C.textFaint),
              ],
            ),
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLearn});

  final VoidCallback onLearn;

  @override
  Widget build(BuildContext context) => Tap(
        label: Voltkit.poweredBy,
        onTap: onLearn,
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.lg),
            gradient: diagonal(const [Color(0xFF2A1159), Color(0xFF5B1FA8), Color(0xFFC026D3)]),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(right: -6, top: -14, child: Asset(Art.crown, width: 124, height: 124, fit: BoxFit.contain)),
              Padding(
                padding: const EdgeInsets.only(right: 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Your room.', variant: V.title),
                    const SizedBox(height: 2),
                    const T('Your layout.', variant: V.title),
                    const SizedBox(height: 6),
                    const T(Voltkit.demoLine, variant: V.small, color: Color(0xCCFFFFFF), lines: 1),
                    const SizedBox(height: 6),
                    Row(
                      children: gapped(4, horizontal: true, const [
                        T('Build yours at voltkit.in', variant: V.tiny, color: C.gold),
                        Icon(Ion.arrowForward, size: 12, color: C.gold),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TabFocus {
  @override
  int get tabIndex => 0;

  var _filter = 'all';
  var _rooms = <Room>[];
  int? _online;
  var _loaded = false;
  String? _error;
  final _off = <void Function()>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _off.addAll([
      liveSocket.on('rooms:changed', (_) => _load()),
      // Once the live connection is up, and after each reconnect: the count includes this phone, and rooms missed
      // while offline appear.
      liveSocket.on('connect', (_) => _load()),
    ]);
  }

  @override
  void dispose() {
    for (final off in _off) {
      off();
    }
    super.dispose();
  }

  @override
  void onFocus() => unawaited(_load());

  Future<void> _load() async {
    try {
      final results = await Future.wait([api.rooms(), api.stats()]);
      if (!mounted) return;
      setState(() {
        _rooms = results[0] as List<Room>;
        _online = (results[1] as Stats).online;
        _error = null;
        _loaded = true;
      });
    } on ApiError catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loaded = true;
      });
    }
  }

  void _open(Room room) => unawaited(Navigator.of(context).push(fadeRoute(RoomScreen(roomId: room.id))));
  void _create(String type) => unawaited(Navigator.of(context).push(bottomRoute(CreateScreen(type: type))));

  Widget _top(Guest guest) => Row(
        children: [
          const Asset(Art.mark, width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 7),
          const Wordmark(size: 23),
          const SizedBox(width: 7),
          const T('Live', variant: V.heading, color: C.textDim),
          const Spacer(),
          if (_online != null) ...[
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(R.pill)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.success, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  T('${compact(_online!)} online', variant: V.tiny),
                ],
              ),
            ),
            const SizedBox(width: 7),
          ],
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(color: const Color(0x1FFFD765), borderRadius: BorderRadius.circular(R.pill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Ion.logoBitcoin, size: 14, color: C.gold),
                const SizedBox(width: 4),
                T(compact(guest.coins), variant: V.tiny, color: C.gold),
              ],
            ),
          ),
        ],
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Semantics(
          identifier: 'home-empty',
          child: Column(
            children: gapped(
              10,
              _error != null
                  ? [
                      const Icon(Ion.cloudOfflineOutline, size: 40, color: C.textDim),
                      T(_error!, color: C.textDim, align: TextAlign.center),
                      GradientButton(label: 'Try again', onTap: () => unawaited(_load())),
                    ]
                  : [
                      const Icon(Ion.radioOutline, size: 42, color: C.magenta),
                      const T('Nobody is live right now', variant: V.heading),
                      const T('Start the first room and be the one others find.', color: C.textDim, align: TextAlign.center),
                      GradientButton(id: 'home-empty-create', label: 'Go live', icon: Ion.radio, onTap: () => _create(_filter == 'audio' ? 'audio' : 'video')),
                    ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final guest = SessionScope.of(context).guest;
    final top = MediaQuery.paddingOf(context).top;
    final shown = _filter == 'all' ? _rooms : _rooms.where((r) => r.type == _filter).toList();
    return Backdrop(
      child: RefreshIndicator(
        color: C.magenta,
        backgroundColor: C.plum,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _top(guest),
                    const SizedBox(height: 14),
                    _Hero(onLearn: () => unawaited(Navigator.of(context).push(slideRoute(const VoltKitScreen())))),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _QuickAction(id: 'go-video', icon: Ion.videocam, title: 'Go live', hint: 'Video room', tint: G.video, onTap: () => _create('video')),
                        const SizedBox(width: 10),
                        _QuickAction(id: 'go-audio', icon: Ion.mic, title: 'Audio room', hint: 'Seats and voices', tint: G.audio, onTap: () => _create('audio')),
                        const SizedBox(width: 10),
                        _QuickAction(id: 'go-match', icon: Ion.shuffle, title: '1v1 Face', hint: 'Meet someone', tint: G.match, onTap: () => unawaited(Navigator.of(context).push(fadeRoute(const MatchScreen())))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: gapped(8, horizontal: true, [
                        for (final (id, label, icon) in _filters)
                          Tap(
                            id: 'filter-$id',
                            label: label,
                            selected: _filter == id,
                            onTap: () => setState(() => _filter = id),
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 13),
                              decoration: BoxDecoration(color: _filter == id ? C.purple : C.glass, borderRadius: BorderRadius.circular(R.pill)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 13, color: _filter == id ? C.white : C.textDim),
                                  const SizedBox(width: 5),
                                  T(label, variant: V.small, color: _filter == id ? C.white : C.textDim),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              SliverToBoxAdapter(child: _loaded ? _empty() : const SizedBox.shrink())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.74),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _RoomCard(key: ValueKey(shown[i].id), room: shown[i], onTap: _open),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 28, 14, 110),
              sliver: SliverToBoxAdapter(child: BuiltWith()),
            ),
          ],
        ),
      ),
    );
  }
}
