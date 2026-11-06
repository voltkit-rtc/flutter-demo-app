import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../../theme.dart';
import '../../types.dart';
import '../ui.dart';

class ChatLine {
  const ChatLine({required this.id, required this.kind, required this.text, this.from, this.name, this.avatar, this.frame});

  final String id;

  /// `text`, `gift` or `notice`.
  final String kind;
  final String? from;
  final String? name;
  final String? avatar;
  final Frame? frame;
  final String text;
}

const _maxLines = 120;
const _welcome = ChatLine(
  id: 'welcome',
  kind: 'notice',
  text: 'Welcome. Be kind: harassment, nudity and spam get you removed. Tap anyone to report or block them.',
);

ChatLine? toLine(ChatMessage m) {
  final meta = m.metadata ?? const {};
  if (m.type == 'text' && (m.text?.trim().isNotEmpty ?? false)) {
    return ChatLine(
      id: m.id,
      kind: 'text',
      from: m.from,
      name: meta['name'] as String? ?? 'Guest',
      avatar: meta['avatar'] as String?,
      frame: meta['frame'] as String?,
      text: m.text!,
    );
  }
  if (m.type == 'gift') {
    final count = (meta['count'] as num?)?.toInt() ?? 1;
    final times = count > 1 ? ' ×$count' : '';
    return ChatLine(
      id: m.id,
      kind: 'gift',
      from: m.from,
      text: '${meta['fromName'] ?? 'Someone'} sent ${meta['giftName'] ?? 'a gift'}$times to ${meta['toName'] ?? 'the host'}',
    );
  }
  return null;
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.line, required this.onTap});

  final ChatLine line;
  final void Function(ChatLine line) onTap;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 20;
    if (line.kind == 'notice') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.92),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0x6B000000), borderRadius: BorderRadius.circular(R.sm)),
          child: T(line.text, variant: V.tiny, color: C.cyan),
        ),
      );
    }
    final bubble = BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(R.md));
    if (line.kind == 'gift') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: bubble,
          child: T(line.text, variant: V.small, color: C.gold),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Tap(
        label: 'Message from ${line.name}: ${line.text}',
        onTap: () => onTap(line),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: bubble,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(avatar: line.avatar, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: textStyle(V.small),
                    children: [
                      TextSpan(text: '${line.name}  ', style: textStyle(V.small, color: C.gold)),
                      TextSpan(text: line.text),
                    ],
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat lives on the room's own connection, so there is no second socket and no second token.
class RoomChat extends StatefulWidget {
  const RoomChat({super.key, required this.client, required this.selfId, required this.blocked, required this.onTapLine});

  final StreamClient client;
  final String selfId;
  final List<String> blocked;
  final void Function(ChatLine line) onTapLine;

  @override
  State<RoomChat> createState() => _RoomChatState();
}

class _RoomChatState extends State<RoomChat> {
  var _lines = <ChatLine>[_welcome];
  final _greeted = <String>{};
  var _loaded = false;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _subs.addAll([
      c.onMessage.listen((m) {
        if (widget.blocked.contains(m.from)) return;
        final line = toLine(m);
        if (line != null) _push(line);
      }),
      c.onMessageDeleted.listen((e) => setState(() => _lines = _lines.where((l) => l.id != e.id).toList())),
      c.onConnectionStateChanged.listen((s) {
        if (s.state == SessionState.connected) _load();
      }),
      // A Flutter client's name comes with the join. A React Native one's comes just after, as an update.
      c.onParticipantJoined.listen((p) => _greet(p.identity, p.metadata)),
      c.onParticipantUpdated.listen((p) => _greet(p.identity, p.metadata)),
    ]);
    if (c.connectionState == SessionState.connected) _load();
  }

  void _push(ChatLine line) {
    if (!mounted || _lines.any((l) => l.id == line.id)) return;
    setState(() {
      _lines = [line, ..._lines];
      if (_lines.length > _maxLines) _lines = _lines.sublist(0, _maxLines);
    });
  }

  void _greet(String identity, Map<String, dynamic>? metadata) {
    if (identity == widget.selfId) return;
    final name = metadata?['name'];
    if (name is! String || !_greeted.add(identity)) return;
    _push(ChatLine(id: 'joined-$identity-${DateTime.now().millisecondsSinceEpoch}', kind: 'notice', text: '$name joined'));
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    // Whoever is already here has already arrived.
    _greeted.addAll(widget.client.participants.map((p) => p.identity));
    try {
      final history = await widget.client.getMessages(limit: 30);
      if (!mounted) return;
      final old = history.map(toLine).whereType<ChatLine>().where((l) => !widget.blocked.contains(l.from)).toList().reversed;
      setState(() {
        _lines = [..._lines.where((l) => l.id != 'welcome'), ...old, _welcome];
        if (_lines.length > _maxLines) _lines = _lines.sublist(0, _maxLines);
      });
    } catch (_) {
      // The chat works without its history.
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: Semantics(
          identifier: 'room-chat',
          child: ListView.separated(
            reverse: true,
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 6),
            itemCount: _lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 5),
            itemBuilder: (context, i) => _Line(key: ValueKey(_lines[i].id), line: _lines[i], onTap: widget.onTapLine),
          ),
        ),
      );
}
