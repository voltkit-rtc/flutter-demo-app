import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../../icons.dart';
import '../../theme.dart';

const _maxOnScreen = 12;
const _tints = [C.pink, C.magenta, C.purple, C.gold];
final _random = math.Random();

class _Heart extends StatefulWidget {
  const _Heart({super.key, required this.seq, required this.onDone});

  final int seq;
  final void Function(int seq) onDone;

  @override
  State<_Heart> createState() => _HeartState();
}

class _HeartState extends State<_Heart> with SingleTickerProviderStateMixin {
  late final _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final _eased = CurvedAnimation(parent: _p, curve: Curves.easeOutQuad);
  final _sway = 10 + _random.nextDouble() * 30;
  final _side = _random.nextBool() ? 1.0 : -1.0;

  @override
  void initState() {
    super.initState();
    _p.forward().whenComplete(() {
      if (mounted) widget.onDone(widget.seq);
    });
  }

  @override
  void dispose() {
    _eased.dispose();
    _p.dispose();
    super.dispose();
  }

  double _between(double p, List<double> at, List<double> values) {
    for (var i = 1; i < at.length; i++) {
      if (p <= at[i]) {
        final t = (p - at[i - 1]) / (at[i] - at[i - 1]);
        return values[i - 1] + (values[i] - values[i - 1]) * t;
      }
    }
    return values.last;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _eased,
        builder: (context, child) {
          final p = _eased.value;
          final x = _between(p, const [0, 0.5, 1], [0, _side * _sway, -_side * _sway * 0.5]);
          return Transform.translate(
            offset: Offset(x, -280 * p),
            child: Transform.scale(
              scale: _between(p, const [0, 0.15, 1], const [0.4, 1.15, 0.9]),
              child: Opacity(opacity: _between(p, const [0, 0.1, 0.7, 1], const [0, 1, 0.9, 0]), child: child),
            ),
          );
        },
        child: Icon(Ion.heart, size: 30, color: _tints[widget.seq % _tints.length]),
      );
}

/// Hearts from everyone. They travel as ephemeral chat messages, which are delivered and never stored.
class Reactions extends StatefulWidget {
  const Reactions({super.key, required this.client});

  final StreamClient client;

  @override
  State<Reactions> createState() => _ReactionsState();
}

class _ReactionsState extends State<Reactions> {
  var _hearts = <int>[];
  var _seq = 0;
  late final StreamSubscription<ChatMessage> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.onMessage.listen((m) {
      if (m.type != 'reaction' || _hearts.length >= _maxOnScreen) return;
      setState(() => _hearts = [..._hearts, ++_seq]);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        right: 26,
        bottom: 96 + MediaQuery.paddingOf(context).bottom,
        width: 40,
        height: 30,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final seq in _hearts)
                  _Heart(key: ValueKey(seq), seq: seq, onDone: (done) => setState(() => _hearts = _hearts.where((h) => h != done).toList())),
              ],
            ),
          ),
        ),
      );
}
