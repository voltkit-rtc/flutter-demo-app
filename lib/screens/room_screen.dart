import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart' show ClosedReason, SessionState;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/client.dart';
import '../app_assets.dart';
import '../components/room/chat.dart';
import '../components/room/reactions.dart';
import '../components/room/sheets.dart';
import '../components/room/stage_audio.dart';
import '../components/room/stage_video.dart';
import '../components/ui.dart';
import '../gifts/gift_sheet.dart';
import '../gifts/gift_stage.dart';
import '../icons.dart';
import '../rtc/errors.dart';
import '../rtc/permissions.dart';
import '../rtc/room_engine.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/routes.dart';
import '../util/toast.dart';
import 'chat_screens.dart';

class _Banners extends StatelessWidget {
  const _Banners({required this.engine});

  final RoomEngine engine;

  @override
  Widget build(BuildContext context) {
    final reconnecting = engine.state == SessionState.reconnecting;
    if (!reconnecting && !engine.walletLow) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, top: 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: reconnecting ? const Color(0x99000000) : const Color(0xD9FB3B66),
        borderRadius: BorderRadius.circular(R.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: reconnecting
            ? const [Spinner(color: C.white, size: 16), SizedBox(width: 8), T('Reconnecting…', variant: V.small)]
            : const [T('Demo credit is running out. This room may end soon.', variant: V.small)],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.engine, required this.onPeople, required this.onMore, required this.onHost});

  final RoomEngine engine;
  final VoidCallback onPeople;
  final VoidCallback onMore;
  final VoidCallback onHost;

  @override
  Widget build(BuildContext context) {
    final room = engine.room;
    final pending = canModerate(engine.myRole) ? engine.hands.length : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                label: 'Host',
                onTap: onHost,
                child: Container(
                  padding: const EdgeInsets.only(left: 3, right: 12, top: 3, bottom: 3),
                  decoration: BoxDecoration(color: const Color(0x6B000000), borderRadius: BorderRadius.circular(R.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Avatar(avatar: room.host.avatar, size: 36),
                      const SizedBox(width: 7),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              T(room.title, variant: V.small, lines: 1),
                              T(room.host.name, variant: V.tiny, lines: 1, color: C.textDim),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          TagChip(icon: Ion.trophy, label: compact(engine.roomCoins), tint: C.gold),
          const SizedBox(width: 6),
          const LivePill(),
          const SizedBox(width: 6),
          IconBtn(id: 'room-people', size: 34, icon: Ion.people, label: 'People, ${engine.members.length}', badge: pending, onTap: onPeople),
          const SizedBox(width: 6),
          IconBtn(id: 'room-more', size: 34, icon: Ion.ellipsisHorizontal, label: 'Room menu', onTap: onMore),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.engine, required this.draft, required this.onChat, required this.onGift, required this.onHeart, required this.onMore});

  final RoomEngine engine;
  final TextEditingController draft;
  final VoidCallback onChat;
  final VoidCallback onGift;
  final VoidCallback onHeart;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final video = engine.room.isVideo;
    final muted = engine.iMutedInChat;
    final micLive = engine.publishing && engine.micEnabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: gapped(6, horizontal: true, [
          Expanded(
            child: Tap(
              id: 'chat-open',
              label: 'Write a message',
              onTap: muted ? null : onChat,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(color: C.glassStrong, borderRadius: BorderRadius.circular(R.pill)),
                child: Row(
                  children: [
                    Icon(muted ? Ion.lockClosed : Ion.chatbubbleEllipses, size: 15, color: C.textDim),
                    const SizedBox(width: 7),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: draft,
                        builder: (context, value, _) => T(
                          muted ? 'Muted' : (value.text.isEmpty ? 'Say hi…' : value.text),
                          variant: V.small,
                          lines: 1,
                          color: value.text.isEmpty ? C.textDim : C.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (canPublish(engine.myRole)) ...[
            IconBtn(id: 'ctl-mic', size: 42, icon: micLive ? Ion.mic : Ion.micOff, danger: !micLive, label: engine.micEnabled ? 'Mute' : 'Unmute', onTap: () => unawaited(engine.toggleMic())),
            if (video)
              IconBtn(id: 'ctl-cam', size: 42, icon: engine.camEnabled ? Ion.videocam : Ion.videocamOff, danger: !engine.camEnabled, label: engine.camEnabled ? 'Camera off' : 'Camera on', onTap: () => unawaited(engine.toggleCam())),
            if (video) IconBtn(id: 'ctl-flip', size: 42, icon: Ion.cameraReverse, label: 'Flip camera', onTap: () => unawaited(engine.flipCamera())),
          ] else ...[
            if (engine.myRole.name == 'viewer')
              IconBtn(
                id: 'ctl-hand',
                size: 42,
                icon: Ion.handLeft,
                active: engine.myHand,
                label: engine.myHand ? 'Cancel request' : 'Ask to join the stage',
                onTap: () => unawaited(engine.myHand ? engine.cancelRequest() : engine.requestSeat()),
              ),
            IconBtn(id: 'ctl-heart', size: 42, icon: Ion.heart, tint: C.pink, label: 'Send a heart', onTap: onHeart),
          ],
          IconBtn(id: 'ctl-gift', size: 42, icon: Ion.gift, tint: C.gold, label: 'Send a gift', onTap: onGift),
          IconBtn(size: 42, icon: Ion.grid, label: 'Room menu', onTap: onMore),
        ]),
      ),
    );
  }
}

/// The message box, above the keyboard. When the keyboard goes away it closes too and the draft stays in the "Say hi"
/// pill, so what was typed is neither hidden nor lost.
class _Composer extends StatefulWidget {
  const _Composer({required this.draft, required this.onClose, required this.onSend});

  final TextEditingController draft;
  final VoidCallback onClose;
  final void Function(String text) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  var _keyboardWasUp = false;

  void _send() {
    final body = widget.draft.text.trim();
    if (body.isNotEmpty) widget.onSend(body);
    widget.draft.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onClose();
  }

  void _dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    if (keyboard > 0) {
      _keyboardWasUp = true;
    } else if (_keyboardWasUp) {
      _keyboardWasUp = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dismiss();
      });
    }
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _dismiss),
          ),
          Container(
            margin: EdgeInsets.only(bottom: keyboard > 0 ? keyboard : media.padding.bottom),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: C.plum,
            child: Row(
              children: [
                Expanded(
                  child: Field(
                    id: 'chat-input',
                    controller: widget.draft,
                    autofocus: true,
                    hint: 'Say something nice',
                    maxLength: 280,
                    height: 42,
                    radius: R.pill,
                    fontSize: 15,
                    weight: FontWeight.w400,
                    action: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconBtn(id: 'chat-send', icon: Ion.send, size: 40, active: true, label: 'Send', onTap: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomView extends StatefulWidget {
  const _RoomView({super.key, required this.engine, required this.onExit});

  final RoomEngine engine;
  final VoidCallback onExit;

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  RoomEngine get engine => widget.engine;
  final _draft = TextEditingController();
  var _composing = false;
  var _inviteOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    engine.addListener(_watchInvite);
    loadCatalog().then((gifts) => preloadGifts(gifts.map((g) => g.svgaUrl).toList()), onError: (Object _) {});
  }

  void _watchInvite() {
    if (engine.invitedTo == null || _inviteOpen || !mounted) return;
    _inviteOpen = true;
    showInviteSheet(context, engine).whenComplete(() => _inviteOpen = false);
  }

  @override
  void dispose() {
    engine.removeListener(_watchInvite);
    unawaited(WakelockPlus.disable());
    _draft.dispose();
    super.dispose();
  }

  void _sendChat(String text) {
    final me = engine.me;
    engine.client.sendMessage(text, metadata: {'name': me.name, 'avatar': me.avatar, 'frame': me.frame}).catchError((Object err) {
      toast(actionProblem(err), ToastKind.error);
      return (id: '', ts: 0);
    });
  }

  void _sendHeart() {
    engine.client.sendMessage('', type: 'reaction', metadata: const {'emoji': 'heart'}, ephemeral: true).catchError((Object _) => (id: '', ts: 0));
  }

  void _member(String identity, {String? messageId}) => showMemberSheet(
        context,
        engine: engine,
        identity: identity,
        messageId: messageId,
        onGift: _gift,
        onReport: _report,
        onMessage: _openThread,
      );

  void _report(String id, String name) => showReportSheet(context, id: id, name: name, roomId: engine.room.id);

  void _gift([String? to]) {
    int place(Member m) => m.identity == engine.room.host.id ? 0 : (m.seat != null ? 1 : 2);
    final people = [...engine.members]..sort((a, b) => place(a).compareTo(place(b)));
    showSheet<void>(
      context,
      id: 'gift-sheet',
      builder: (context) => GiftSheet(room: engine.room, people: people.take(40).toList(), initialTo: to),
    );
  }

  void _people() => showPeopleSheet(context, engine, _member);

  void _more() => showMoreSheet(
        context,
        engine: engine,
        onLeave: _confirmExit,
        onPeople: _people,
        onReportRoom: () => _report(engine.room.host.id, engine.room.title),
      );

  Future<void> _confirmExit() async {
    if (!await showConfirmEnd(context, isHost: engine.isHost)) return;
    widget.onExit();
  }

  Future<void> _openThread(String identity) async {
    final navigator = Navigator.of(context);
    try {
      final conversation = await api.startConversation(identity);
      unawaited(navigator.push(slideRoute(ThreadScreen(conversationId: conversation.id, peer: conversation.peer))));
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final insets = media.padding;
    final room = engine.room;
    // Header, gaps and controls take the rest; the chat gets whatever is left under the stage.
    final stageHeight = ((size.height - insets.top - insets.bottom) * 0.58).roundToDouble();
    final blocked = SessionScope.of(context).guest.blocked;
    return PopScope(
      // The room can only be left on purpose: a stray back press should not end someone's live. A pushed chat is its
      // own route, so back there just closes the chat.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Stack(
        children: [
          Positioned.fill(child: Asset(coverAsset(room.theme), width: size.width, height: size.height)),
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: vertical(const [Color(0xD1080610), Color(0x94080610), Color(0xF0080610)]))),
          ),
          Padding(
            padding: EdgeInsets.only(top: insets.top + 6, bottom: insets.bottom + 6),
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: engine,
                  builder: (context, _) => Column(
                    children: [
                      _Header(engine: engine, onPeople: _people, onMore: _more, onHost: () => _member(room.host.id)),
                      _Banners(engine: engine),
                      Padding(
                        padding: EdgeInsets.only(left: room.isVideo ? 6 : 0, right: room.isVideo ? 6 : 0, top: 8),
                        child: room.isVideo
                            ? VideoStage(engine: engine, width: size.width - 12, height: stageHeight, onMember: _member, onSeat: (key) => showSeatSheet(context, engine, key))
                            : AudioStage(engine: engine, onMember: _member, onSeat: (key) => showSeatSheet(context, engine, key)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: RoomChat(
                    client: engine.client,
                    selfId: engine.me.id,
                    blocked: blocked,
                    onTapLine: (line) {
                      if (line.from != null) _member(line.from!, messageId: line.id);
                    },
                  ),
                ),
                const PoweredBy(),
                const SizedBox(height: 4),
                ListenableBuilder(
                  listenable: engine,
                  builder: (context, _) => _ControlBar(
                    engine: engine,
                    draft: _draft,
                    onChat: () => setState(() => _composing = true),
                    onGift: _gift,
                    onHeart: _sendHeart,
                    onMore: _more,
                  ),
                ),
              ],
            ),
          ),
          Reactions(client: engine.client),
          GiftStage(client: engine.client),
          if (_composing) _Composer(draft: _draft, onClose: () => setState(() => _composing = false), onSend: _sendChat),
        ],
      ),
    );
  }
}

/// Owns a room session: gets a token, makes the engine, and decides what to show when it ends. What happens inside a
/// room is in rtc/room_engine.dart.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId, this.initial});

  final String roomId;
  final RoomSession? initial;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomEngine? _engine;
  ({String text, bool canRejoin})? _ended;
  var _exiting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _begin(widget.initial!);
    } else {
      unawaited(_join());
    }
  }

  void _begin(RoomSession session) {
    final me = SessionScope.read(context).guest;
    // A closed session stays closed, so rejoining needs a new client: a new engine is how that happens.
    final engine = RoomEngine(room: session.room, me: me, credentials: session.credentials, onClosed: _onClosed, onFailed: _onFailed);
    _engine = engine;
    WidgetsBinding.instance.addPostFrameCallback((_) => engine.start());
  }

  void _dropEngine() {
    final engine = _engine;
    _engine = null;
    // After the frame: what is on screen still listens to it until then.
    if (engine != null) WidgetsBinding.instance.addPostFrameCallback((_) => engine.dispose());
  }

  Future<void> _join() async {
    setState(() {
      _ended = null;
      _dropEngine();
    });
    try {
      final session = await api.joinRoom(widget.roomId);
      if (mounted) setState(() => _begin(session));
    } on ApiError catch (err) {
      const gone = {'room-ended', 'banned', 'room-full', 'rtc-unavailable'};
      if (mounted) setState(() => _ended = (text: err.message, canRejoin: !gone.contains(err.code)));
    }
  }

  void _closePopups() {
    if (mounted) Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
  }

  void _onClosed(ClosedReason reason) {
    if (_exiting || !mounted) return;
    _closePopups();
    // Left from the notification: this route goes, even under a chat opened from the room.
    if (reason == ClosedReason.left) {
      _exiting = true;
      Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      return;
    }
    setState(() {
      _dropEngine();
      _ended = (text: closedText(reason), canRejoin: reason == ClosedReason.gaveUp);
    });
  }

  void _onFailed(Object err) {
    if (!mounted) return;
    final problem = joinProblem(err);
    _closePopups();
    setState(() {
      _dropEngine();
      _ended = (text: problem.text, canRejoin: problem.canRetry);
    });
  }

  Future<void> _exit() async {
    final engine = _engine;
    final navigator = Navigator.of(context);
    _exiting = true;
    if (engine != null && engine.isHost) await engine.endRoom();
    if (mounted) navigator.pop();
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ended = _ended;
    final engine = _engine;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ended != null
          ? Backdrop(
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: gapped(14, [
                      const Icon(Ion.radioOutline, size: 46, color: C.magenta),
                      T(ended.text, id: 'room-ended-text', variant: V.title, align: TextAlign.center),
                      if (ended.canRejoin) GradientButton(label: 'Join again', onTap: () => unawaited(_join())),
                      GhostButton(id: 'room-ended-home', label: 'Back to home', onTap: () => Navigator.of(context).pop()),
                    ]),
                  ),
                ),
              ),
            )
          : engine == null
              ? const Backdrop(
                  child: SizedBox.expand(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Spinner(size: 36), SizedBox(height: 14), T('Joining…', color: C.textDim)],
                    ),
                  ),
                )
              : _RoomView(key: ObjectKey(engine), engine: engine, onExit: () => unawaited(_exit())),
    );
  }
}
