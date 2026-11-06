import 'dart:async';

import 'package:flutter/material.dart';

import '../components/ui.dart';
import '../theme.dart';

enum ToastKind { info, error, success }

final _toasts = ValueNotifier<({String text, ToastKind kind, int seq})?>(null);
var _seq = 0;

void toast(String text, [ToastKind kind = ToastKind.info]) => _toasts.value = (text: text, kind: kind, seq: ++_seq);

/// Sits over every screen, sheets included.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key});

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> with SingleTickerProviderStateMixin {
  late final _y = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), reverseDuration: const Duration(milliseconds: 200));
  late final _curve = CurvedAnimation(parent: _y, curve: Curves.easeOutCubic);
  Timer? _timer;
  ({String text, ToastKind kind})? _item;

  @override
  void initState() {
    super.initState();
    _toasts.addListener(_show);
  }

  void _show() {
    final next = _toasts.value;
    if (next == null) return;
    setState(() => _item = (text: next.text, kind: next.kind));
    _timer?.cancel();
    _y.forward();
    _timer = Timer(const Duration(milliseconds: 2800), () async {
      await _y.reverse();
      if (mounted) setState(() => _item = null);
    });
  }

  @override
  void dispose() {
    _toasts.removeListener(_show);
    _timer?.cancel();
    _curve.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) return const SizedBox.shrink();
    final tint = switch (item.kind) {
      ToastKind.error => C.danger,
      ToastKind.success => C.success,
      ToastKind.info => C.purple,
    };
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) => Opacity(
              opacity: _curve.value,
              child: Transform.translate(offset: Offset(0, -20 * (1 - _curve.value)), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xF7170B2E),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: tint),
              ),
              child: T(item.text, variant: V.small, align: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
