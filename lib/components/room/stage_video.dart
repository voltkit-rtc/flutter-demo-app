import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../../app_assets.dart';
import '../../icons.dart';
import '../../rtc/layout.dart';
import '../../rtc/room_engine.dart';
import '../../rtc/seats.dart';
import '../../rtc/video_views.dart';
import '../../theme.dart';
import '../../types.dart';
import '../ui.dart';

class _SpeakingEdge extends StatelessWidget {
  const _SpeakingEdge({required this.engine, required this.identity, required this.host});

  final RoomEngine engine;
  final String identity;
  final bool host;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: engine.speaking,
          builder: (context, speaking, _) {
            final on = speaking.contains(identity);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(
                  color: on ? C.cyan : (host ? const Color(0xBFFFD765) : const Color(0x38FFFFFF)),
                  width: on ? 2.5 : 1,
                ),
              ),
            );
          },
        ),
      );
}

/// The glow around someone who is talking. It goes behind the card: a shadow painted over the card fills all of it, and
/// covered the video of whoever was speaking.
class _SpeakingGlow extends StatelessWidget {
  const _SpeakingGlow({required this.engine, required this.identity});

  final RoomEngine engine;
  final String identity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: engine.speaking,
          builder: (context, speaking, _) => !speaking.contains(identity)
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(R.sm),
                    boxShadow: const [BoxShadow(color: C.cyan, blurRadius: 14)],
                  ),
                ),
        ),
      );
}

/// A dashed outline around an empty seat.
class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x21FFFFFF)
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(R.sm)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    super.key,
    required this.engine,
    required this.rect,
    required this.onTap,
    required this.id,
    this.seatLabel,
    this.identity,
    this.name,
    this.avatar,
    this.frame = 'none',
    this.role,
    this.host = false,
    this.micOn = false,
    this.remote,
    this.localStream,
    this.mirror = false,
    this.away = false,
    this.locked = false,
  });

  final RoomEngine engine;
  final Rect rect;
  final VoidCallback onTap;
  final String id;
  final String? seatLabel;
  final String? identity;
  final String? name;
  final String? avatar;
  final Frame frame;
  final Role? role;
  final bool host;
  final bool micOn;
  final RemoteTrack? remote;
  final MediaStream? localStream;
  final bool mirror;
  final bool away;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final compact = rect.width < 150;
    final filled = identity != null;
    final showVideo = localStream != null || remote != null;
    final held = remote?.producerId;
    return Positioned.fromRect(
      rect: rect,
      child: Tap(
        id: id,
        label: filled ? '$name, ${role?.name ?? 'viewer'}' : (locked ? '$seatLabel, locked' : '$seatLabel, empty'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (filled) _SpeakingGlow(engine: engine, identity: identity!),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.sm),
              child: filled
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: vertical(host ? const [Color(0xFF3B2A08), Color(0xFF170B2E)] : const [Color(0xFF241243), Color(0xFF0D0720)]),
                          ),
                        ),
                        Center(child: Avatar(avatar: avatar, size: rect.shortestSide * (compact ? 0.42 : 0.34))),
                        if (remote != null) RemoteVideo(key: ValueKey(remote!.producerId), client: engine.client, track: remote!),
                        if (localStream != null) LocalVideo(stream: localStream!, mirror: mirror),
                        if (held != null && !compact)
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: engine.held,
                            builder: (context, list, _) => !list.contains(held)
                                ? const SizedBox.shrink()
                                : Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                                      child: const T('Weak connection', variant: V.tiny),
                                    ),
                                  ),
                          ),
                        if (away) const ColoredBox(color: Color(0x8C000000)),
                        _SpeakingEdge(engine: engine, identity: identity!, host: host),
                        if ((frame == 'lion' || frame == 'wolf') && showVideo)
                          Positioned(
                            top: compact ? 2 : 4,
                            right: compact ? 2 : 4,
                            child: Asset(crestAsset(frame), width: compact ? 28 : 42, height: compact ? 28 : 42, fit: BoxFit.contain),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 44,
                          child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: vertical(G.scrimBottom)))),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: micOn ? const Color(0x38FFFFFF) : C.danger),
                                child: Icon(micOn ? Ion.mic : Ion.micOff, size: 10, color: C.white),
                              ),
                              const SizedBox(width: 5),
                              Expanded(child: T(away ? 'Reconnecting…' : name ?? '', variant: V.tiny, lines: 1)),
                            ],
                          ),
                        ),
                        if (role != null) Positioned(top: 6, left: 6, child: RoleBadge(role: role!.name)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0x0DFFFFFF)),
                        const CustomPaint(painter: _DashedBorder()),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(locked ? Ion.lockClosed : Ion.add, size: compact ? 22 : 28, color: C.textDim),
                            const SizedBox(height: 4),
                            T(seatLabel ?? '', variant: V.tiny, color: C.textFaint),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoStage extends StatelessWidget {
  const VideoStage({super.key, required this.engine, required this.width, required this.height, required this.onMember, required this.onSeat});

  final RoomEngine engine;
  final double width;
  final double height;
  final void Function(String identity) onMember;
  final void Function(String key) onSeat;

  @override
  Widget build(BuildContext context) {
    final room = engine.room;
    final rects = videoLayout(room.seats, engine.layout, width, height);
    final camera = engine.camEnabled && (engine.localStream?.getVideoTracks().isNotEmpty ?? false) ? engine.localStream : null;

    _VideoCard card(String id, Rect rect, VoidCallback onTap, {Member? member, GuestPublic? fallback, String? seatLabel, bool locked = false, bool away = false, bool host = false}) {
      final identity = member?.identity ?? fallback?.id;
      final mine = identity == engine.me.id;
      return _VideoCard(
        key: ValueKey(id),
        engine: engine,
        id: id,
        rect: rect,
        onTap: onTap,
        seatLabel: seatLabel,
        locked: locked,
        away: away,
        host: host,
        identity: identity,
        name: identity == null ? null : (mine ? '${member?.name ?? engine.me.name} (you)' : member?.name ?? fallback?.name),
        avatar: member?.avatar ?? fallback?.avatar,
        frame: member?.frame ?? fallback?.frame ?? 'none',
        role: host ? Role.host : member?.role,
        micOn: identity != null && engine.micIsOn(identity),
        remote: identity != null && !mine && engine.videoIsOn(identity) ? engine.videoById[identity] : null,
        localStream: mine ? camera : null,
        mirror: mine && engine.frontCamera,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          card('video-card-host', rects[0], () => onMember(room.host.id), member: engine.memberById[room.host.id], fallback: room.host, seatLabel: 'Host', host: true),
          for (final (i, key) in allSeats(engine.seats).indexed)
            () {
              final claim = engine.claims[key];
              return card(
                'video-card-$key',
                rects[i + 1],
                () => claim != null ? onMember(claim.identity) : onSeat(key),
                member: claim == null ? null : engine.memberById[claim.identity],
                fallback: claim == null ? null : GuestPublic(id: claim.identity, name: 'Guest', avatar: 'a01', frame: 'none'),
                seatLabel: 'No.${seatNumber(key)}',
                locked: engine.locked.contains(key),
                away: claim?.away ?? false,
              );
            }(),
        ],
      ),
    );
  }
}
