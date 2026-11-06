import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../api/client.dart';
import '../api/socket.dart';
import '../components/room/sheets.dart';
import '../components/ui.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/routes.dart';
import '../util/toast.dart';
import 'tabs.dart';

/// Chat outside a room: the inbox, the Public Lounge and direct messages, each over a chat-only ChatClient. Room chat
/// is in components/room/chat.dart.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with TabFocus {
  @override
  int get tabIndex => 2;

  var _list = <ConversationSummary>[];
  var _loaded = false;
  late final void Function() _off;

  @override
  void initState() {
    super.initState();
    _off = liveSocket.on('dm:new', (_) => _load());
  }

  @override
  void dispose() {
    _off();
    super.dispose();
  }

  @override
  void onFocus() => unawaited(_load());

  Future<void> _load() async {
    try {
      final list = await api.conversations();
      if (mounted) setState(() => _list = list);
    } on ApiError {
      // The lounge still works, and the next focus tries again.
    }
    if (mounted) setState(() => _loaded = true);
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const T('Chat', variant: V.display),
            const SizedBox(height: 12),
            Tap(
              id: 'open-lounge',
              label: 'Public lounge',
              onTap: () => unawaited(Navigator.of(context).push(slideRoute(const LoungeScreen()))),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.lg), gradient: diagonal(const [Color(0xFF3A1578), Color(0xFF9D2BC0)])),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Color(0x2EFFFFFF), shape: BoxShape.circle),
                      child: const Icon(Ion.planet, size: 24, color: C.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T('Public Lounge', variant: V.heading),
                          T('Talk with everyone online', variant: V.small, color: Color(0xBFFFFFFF)),
                        ],
                      ),
                    ),
                    const Icon(Ion.chevronForward, size: 20, color: C.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const T('Direct messages', variant: V.small, color: C.textDim),
          ],
        ),
      );

  Widget _row(ConversationSummary item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tap(
          id: 'conversation-${item.peer.id}',
          label: 'Conversation with ${item.peer.name}',
          onTap: () => unawaited(Navigator.of(context).push(slideRoute(ThreadScreen(conversationId: item.id, peer: item.peer)))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(R.md)),
            child: Row(
              children: [
                Avatar(avatar: item.peer.avatar, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T(item.peer.name, variant: V.medium, lines: 1),
                      T(item.last?.text ?? 'Say hello', variant: V.small, lines: 1, color: C.textDim),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.last != null) T(shortTime(item.last!.at), variant: V.tiny, color: C.textFaint),
                    if (item.unread > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 19),
                        height: 19,
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.pink, borderRadius: BorderRadius.circular(10)),
                        child: T('${item.unread}', variant: V.tiny, size: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Backdrop(
        child: Semantics(
          identifier: 'inbox-list',
          child: ListView(
            padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 12, 14, 110),
            children: [
              _header(),
              if (_list.isEmpty && _loaded)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Ion.chatbubblesOutline, size: 36, color: C.textDim),
                      SizedBox(height: 10),
                      T('No messages yet. Tap someone in a room to start a conversation.', color: C.textDim, align: TextAlign.center),
                    ],
                  ),
                ),
              for (final item in _list) _row(item),
            ],
          ),
        ),
      );
}

class _Bubble {
  const _Bubble({required this.id, required this.mine, required this.text, this.name, this.avatar, this.from});

  final String id;
  final bool mine;
  final String text;
  final String? name;
  final String? avatar;
  final String? from;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.item, required this.showName, this.onName});

  final _Bubble item;
  final bool showName;
  final void Function(_Bubble bubble)? onName;

  @override
  Widget build(BuildContext context) {
    final named = showName && !item.mine;
    const round = Radius.circular(18);
    const tight = Radius.circular(5);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Row(
      mainAxisAlignment: item.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (named) ...[
          Tap(label: item.name, onTap: () => onName?.call(item), child: Avatar(avatar: item.avatar, size: 30)),
          const SizedBox(width: 6),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: item.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (named)
                Tap(
                  label: '${item.name}, options',
                  onTap: () => onName?.call(item),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: T(item.name ?? 'Guest', variant: V.tiny, color: C.gold),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  gradient: item.mine ? diagonal(G.video) : null,
                  color: item.mine ? null : C.glassStrong,
                  borderRadius: BorderRadius.only(topLeft: round, topRight: round, bottomLeft: item.mine ? round : tight, bottomRight: item.mine ? tight : round),
                ),
                child: T(item.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.id, required this.onSend, this.disabled = false});

  final String id;
  final void Function(String text) onSend;
  final bool disabled;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    widget.onSend(body);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Container(
      color: C.plum,
      padding: EdgeInsets.only(left: 10, right: 10, top: 8, bottom: (keyboard > 0 ? keyboard : media.padding.bottom) + 8),
      child: Row(
        children: [
          Expanded(
            child: Field(
              id: widget.id,
              controller: _text,
              hint: 'Message',
              maxLength: 1000,
              height: 44,
              radius: R.pill,
              fontSize: 15,
              weight: FontWeight.w400,
              enabled: !widget.disabled,
              action: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconBtn(id: '${widget.id}-send', icon: Ion.send, active: true, size: 44, label: 'Send', disabled: widget.disabled, onTap: _send),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.title, required this.onBack, this.subtitle, this.avatar, this.right});

  final String title;
  final String? subtitle;
  final String? avatar;
  final Widget? right;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 8, 12, 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.glassBorder, width: hairline(context)))),
        child: Row(
          children: [
            IconBtn(
              id: 'chat-back',
              size: 38,
              icon: Ion.chevronBack,
              label: 'Back',
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                onBack();
              },
            ),
            const SizedBox(width: 10),
            if (avatar != null) ...[Avatar(avatar: avatar, size: 38), const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(title, variant: V.heading, lines: 1),
                  if (subtitle != null) T(subtitle!, variant: V.tiny, lines: 1, color: C.textDim),
                ],
              ),
            ),
            ?right,
          ],
        ),
      );
}

enum _LinkState { connecting, connected, failed }

/// One chat channel over its own VoltKit connection: no room, no media, just messages.
class _ChatLink {
  _ChatLink({required this.open, required this.onMessage, required this.onState, this.onHistory});

  final Future<ChatChannel> Function() open;
  final void Function(ChatMessage message) onMessage;
  final void Function(_LinkState state) onState;
  final void Function(List<ChatMessage> history)? onHistory;

  ChatClient? client;
  final _subs = <StreamSubscription<dynamic>>[];
  var _cancelled = false;

  Future<void> start() async {
    try {
      final channel = await open();
      if (_cancelled) return;
      final chat = ChatClient(wsUrl: channel.wsUrl, token: channel.token);
      client = chat;
      _subs.addAll([
        chat.onMessage.listen((m) {
          if (!_cancelled) onMessage(m);
        }),
        chat.onClosed.listen((reason) {
          if (reason != ClosedReason.left && !_cancelled) onState(_LinkState.failed);
        }),
        // Whatever was said while the socket was away was not delivered.
        chat.onReconnected.listen((_) async {
          final fill = onHistory;
          if (fill == null) return;
          try {
            final messages = await chat.getMessages(limit: 50);
            if (!_cancelled) fill(messages);
          } catch (_) {
            // The next message still arrives.
          }
        }),
      ]);
      final joined = await chat.connect();
      if (_cancelled) return;
      onHistory?.call(joined.messages);
      onState(_LinkState.connected);
    } catch (_) {
      if (!_cancelled) onState(_LinkState.failed);
    }
  }

  void close() {
    _cancelled = true;
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(client?.close());
    client = null;
  }
}

class LoungeScreen extends StatefulWidget {
  const LoungeScreen({super.key});

  @override
  State<LoungeScreen> createState() => _LoungeScreenState();
}

class _LoungeScreenState extends State<LoungeScreen> {
  var _messages = <_Bubble>[];
  var _state = _LinkState.connecting;
  late final _ChatLink _link;

  @override
  void initState() {
    super.initState();
    _link = _ChatLink(
      open: api.loungeToken,
      onState: (s) => setState(() => _state = s),
      onMessage: (m) {
        final b = _toBubble(m);
        if (b == null || _messages.any((x) => x.id == b.id)) return;
        setState(() {
          _messages = [b, ..._messages];
          if (_messages.length > 200) _messages = _messages.sublist(0, 200);
        });
      },
      onHistory: (history) => setState(() => _messages = history.map(_toBubble).whereType<_Bubble>().toList().reversed.toList()),
    );
    unawaited(_link.start());
  }

  @override
  void dispose() {
    _link.close();
    super.dispose();
  }

  _Bubble? _toBubble(ChatMessage m) {
    final me = SessionScope.read(context).guest;
    final text = m.text;
    if (m.type != 'text' || text == null || text.isEmpty || me.blocked.contains(m.from)) return null;
    final meta = m.metadata ?? const {};
    return _Bubble(id: m.id, mine: m.from == me.id, text: text, name: meta['name'] as String? ?? 'Guest', avatar: meta['avatar'] as String?, from: m.from);
  }

  Future<void> _send(String text) async {
    final me = SessionScope.read(context).guest;
    try {
      await _link.client?.sendMessage(text, metadata: {'name': me.name, 'avatar': me.avatar, 'frame': me.frame});
    } catch (_) {
      toast('Your message was not sent.', ToastKind.error);
    }
  }

  Future<void> _message(_Bubble b) async {
    final navigator = Navigator.of(context);
    try {
      final conversation = await api.startConversation(b.from!);
      unawaited(navigator.push(slideRoute(ThreadScreen(conversationId: conversation.id, peer: conversation.peer))));
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  Future<void> _block(_Bubble b) async {
    final session = SessionScope.read(context);
    try {
      await api.block(b.from!);
      await session.refresh();
      if (mounted) setState(() => _messages = _messages.where((x) => x.from != b.from).toList());
      toast('${b.name} is blocked', ToastKind.success);
    } on ApiError {
      toast('That did not work.', ToastKind.error);
    }
  }

  void _person(_Bubble b) => showSheet<void>(
        context,
        title: b.name,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetRow(
              icon: Ion.chatbubbleEllipsesOutline,
              label: 'Send a message',
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_message(b));
              },
            ),
            SheetRow(
              icon: Ion.flagOutline,
              label: 'Report',
              onTap: () {
                Navigator.pop(sheet);
                unawaited(showReportSheet(context, id: b.from!, name: b.name ?? 'Guest'));
              },
            ),
            SheetRow(
              icon: Ion.banOutline,
              danger: true,
              label: 'Block',
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_block(b));
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: Backdrop(
          child: Column(
            children: [
              _ChatHeader(title: 'Public Lounge', subtitle: 'Chat by VoltKit RTC', onBack: () => Navigator.of(context).pop()),
              if (_state == _LinkState.connecting) const Padding(padding: EdgeInsets.only(top: 40), child: Spinner()),
              if (_state == _LinkState.failed)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: gapped(10, [
                      const T('Could not connect to the lounge.', color: C.textDim),
                      GhostButton(label: 'Back', onTap: () => Navigator.of(context).pop()),
                    ]),
                  ),
                ),
              Expanded(
                child: _messages.isEmpty && _state == _LinkState.connected
                    ? const Center(child: T('It is quiet in here. Say hello.', color: C.textDim, align: TextAlign.center))
                    : Semantics(
                        identifier: 'lounge-list',
                        child: ListView.separated(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _MessageBubble(key: ValueKey(_messages[i].id), item: _messages[i], showName: true, onName: _person),
                        ),
                      ),
              ),
              _InputBar(id: 'lounge-input', onSend: (t) => unawaited(_send(t)), disabled: _state != _LinkState.connected),
            ],
          ),
        ),
      );
}

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.conversationId, required this.peer});

  final String conversationId;
  final GuestPublic peer;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  var _messages = <_Bubble>[];
  late final _ChatLink _link;

  @override
  void initState() {
    super.initState();
    final id = widget.conversationId;
    final me = SessionScope.read(context).guest;
    _link = _ChatLink(
      onState: (_) {},
      open: () async {
        final res = await api.conversation(id);
        if (mounted) setState(() => _messages = res.messages.map((m) => _Bubble(id: m.id, mine: m.from == me.id, text: m.text)).toList());
        unawaited(api.markRead(id).catchError((Object _) {}));
        return res.chat;
      },
      onMessage: (m) {
        final text = m.text;
        if (m.from == me.id || text == null || text.isEmpty) return; // our own already show, from the send below
        final messageId = m.metadata?['messageId'];
        _add(_Bubble(id: messageId is String ? messageId : m.id, mine: false, text: text));
        unawaited(api.markRead(id).catchError((Object _) {}));
      },
    );
    unawaited(_link.start());
  }

  @override
  void dispose() {
    _link.close();
    super.dispose();
  }

  void _add(_Bubble b) {
    if (!mounted || _messages.any((x) => x.id == b.id)) return;
    setState(() => _messages = [b, ..._messages]);
  }

  Future<void> _send(String text) async {
    try {
      final message = await api.sendDirect(widget.conversationId, text);
      _add(_Bubble(id: message.id, mine: true, text: message.text));
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  Future<void> _block() async {
    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);
    try {
      await api.block(widget.peer.id);
      await session.refresh();
      navigator.pop();
      toast('${widget.peer.name} is blocked', ToastKind.success);
    } on ApiError {
      toast('That did not work.', ToastKind.error);
    }
  }

  void _menu() => showSheet<void>(
        context,
        title: widget.peer.name,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetRow(
              icon: Ion.flagOutline,
              label: 'Report',
              onTap: () {
                Navigator.pop(sheet);
                unawaited(showReportSheet(context, id: widget.peer.id, name: widget.peer.name));
              },
            ),
            SheetRow(
              icon: Ion.banOutline,
              danger: true,
              label: 'Block',
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_block());
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: Backdrop(
          child: Column(
            children: [
              _ChatHeader(
                title: widget.peer.name,
                subtitle: 'Direct message',
                avatar: widget.peer.avatar,
                onBack: () => Navigator.of(context).pop(),
                right: IconBtn(id: 'thread-menu', size: 38, icon: Ion.ellipsisHorizontal, label: 'Options', onTap: _menu),
              ),
              Expanded(
                child: Semantics(
                  identifier: 'thread-list',
                  child: ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _MessageBubble(key: ValueKey(_messages[i].id), item: _messages[i], showName: false),
                  ),
                ),
              ),
              _InputBar(id: 'thread-input', onSend: (t) => unawaited(_send(t))),
            ],
          ),
        ),
      );
}
