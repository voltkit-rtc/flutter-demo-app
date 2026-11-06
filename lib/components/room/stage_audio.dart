import 'package:flutter/material.dart';

import '../../app_assets.dart';
import '../../icons.dart';
import '../../rtc/layout.dart';
import '../../rtc/room_engine.dart';
import '../../rtc/seats.dart';
import '../../theme.dart';
import '../../types.dart';
import '../ui.dart';

class SpeakingRing extends StatefulWidget {
  const SpeakingRing({super.key, required this.engine, required this.identity, required this.size});

  final RoomEngine engine;
  final String identity;
  final double size;

  @override
  State<SpeakingRing> createState() => _SpeakingRingState();
}

class _SpeakingRingState extends State<SpeakingRing> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  var _speaking = false;

  @override
  void initState() {
    super.initState();
    widget.engine.speaking.addListener(_update);
    _update();
  }

  void _update() {
    final now = widget.engine.speaking.value.contains(widget.identity);
    if (now == _speaking) return;
    setState(() => _speaking = now);
    if (now) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    widget.engine.speaking.removeListener(_update);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_speaking) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.45 * _pulse.value,
            child: Opacity(opacity: 0.95 * (1 - _pulse.value), child: child),
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.cyan, width: 2.5)),
          ),
        ),
      ),
    );
  }
}

class _MicBadge extends StatelessWidget {
  const _MicBadge({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Positioned(
        bottom: -3,
        right: -3,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? C.blue : C.danger,
            border: Border.all(color: C.plum, width: 1.5),
          ),
          child: Icon(on ? Ion.mic : Ion.micOff, size: 10, color: C.white),
        ),
      );
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.engine,
    required this.label,
    required this.size,
    required this.width,
    required this.onTap,
    required this.id,
    this.identity,
    this.name,
    this.avatar,
    this.frame = 'none',
    this.micOn = false,
    this.away = false,
    this.locked = false,
  });

  final RoomEngine engine;
  final String label;
  final double size;
  final double width;
  final VoidCallback onTap;
  final String id;
  final String? identity;
  final String? name;
  final String? avatar;
  final Frame frame;
  final bool micOn;
  final bool away;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final seated = identity != null;
    return Tap(
      id: id,
      label: seated ? '$name, seat $label' : (locked ? 'Seat $label, locked' : 'Seat $label, empty'),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.glass,
                border: Border.all(color: const Color(0x5978AAFF)),
              ),
              child: seated
                  ? Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        SpeakingRing(engine: engine, identity: identity!, size: size),
                        Opacity(opacity: away ? 0.45 : 1, child: Avatar(avatar: avatar, frame: frame, size: size)),
                        _MicBadge(on: micOn),
                      ],
                    )
                  : Center(
                      child: Container(
                        width: size * 0.66,
                        height: size * 0.66,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x17FFFFFF)),
                        child: Icon(locked ? Ion.lockClosed : Ion.mic, size: size * 0.3, color: C.textDim),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 66),
              child: T(seated ? (away ? 'Reconnecting' : name ?? 'Guest') : label, variant: V.tiny, lines: 1, color: seated ? C.white : C.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioStage extends StatelessWidget {
  const AudioStage({super.key, required this.engine, required this.onMember, required this.onSeat});

  final RoomEngine engine;
  final void Function(String identity) onMember;
  final void Function(String key) onSeat;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final room = engine.room;
    final cols = audioColumns(engine.seats);
    // Whole numbers: cells that add up to the exact width can round over it and wrap a seat onto a new row.
    final cellW = ((width - 20) / cols).floorToDouble();
    final size = (cellW - 18).clamp(0.0, 58.0);
    final host = engine.memberById[room.host.id];
    final hostMic = engine.micIsOn(room.host.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tap(
          id: 'audio-host',
          label: 'Host ${room.host.name}',
          onTap: () => onMember(room.host.id),
          child: SizedBox(
            width: 180,
            height: 142,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                const Asset(Art.throne, width: 128, height: 128, fit: BoxFit.contain),
                Positioned(
                  top: 19,
                  child: SizedBox.square(
                    dimension: 60,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        SpeakingRing(engine: engine, identity: room.host.id, size: 60),
                        Avatar(avatar: host?.avatar ?? room.host.avatar, frame: host?.frame ?? room.host.frame, size: 60),
                        _MicBadge(on: hostMic),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: T(host?.name ?? room.host.name, variant: V.small, lines: 1, color: C.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 12,
            children: [
              for (final key in allSeats(engine.seats))
                Builder(
                  builder: (context) {
                    final claim = engine.claims[key];
                    final m = claim == null ? null : engine.memberById[claim.identity];
                    return _Seat(
                      engine: engine,
                      id: 'audio-$key',
                      width: cellW,
                      size: size,
                      label: 'No.${seatNumber(key)}',
                      identity: claim?.identity,
                      name: m?.name ?? 'Guest',
                      avatar: m?.avatar,
                      frame: m?.frame ?? 'none',
                      micOn: claim != null && engine.micIsOn(claim.identity),
                      away: claim?.away ?? false,
                      locked: engine.locked.contains(key),
                      onTap: () => claim != null ? onMember(claim.identity) : onSeat(key),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
