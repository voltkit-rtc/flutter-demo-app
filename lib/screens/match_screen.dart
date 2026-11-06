import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:voltkit_rtc/voltkit_rtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/client.dart';
import '../api/socket.dart';
import '../components/room/sheets.dart';
import '../components/ui.dart';
import '../icons.dart';
import '../rtc/call_service.dart';
import '../rtc/consent.dart';
import '../rtc/errors.dart';
import '../rtc/video_views.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/toast.dart';

const _peerAway = Duration(seconds: 30);

/// Random 1v1 video calls. A call is a VoltKit room with two people: the backend's matchmaker makes the room and sends
/// each phone its token over Socket.IO.
class _Radar extends StatefulWidget {
  const _Radar();

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _p,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                () {
                  final t = Curves.easeOutQuad.transform((_p.value + i / 3) % 1);
                  return Opacity(
                    opacity: 0.75 * (1 - t),
                    child: Transform.scale(
                      scale: 0.45 + 1.05 * t,
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.pink, width: 2)),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
      );
}

class _CallLine {
  const _CallLine(this.id, this.mine, this.text);

  final String id;
  final bool mine;
  final String text;
}

class _CallView extends StatefulWidget {
  const _CallView({super.key, required this.call, required this.onNext, required this.onStop, required this.onPeerLeft});

  final MatchFound call;
  final VoidCallback onNext;
  final VoidCallback onStop;
  final VoidCallback onPeerLeft;

  @override
  State<_CallView> createState() => _CallViewState();
}

class _CallViewState extends State<_CallView> {
  late final StreamClient _client = StreamClient(
    wsUrl: widget.call.wsUrl,
    token: widget.call.token,
    audioMode: AudioMode.communication,
    pauseCameraInBackground: true,
  );
  final _subs = <StreamSubscription<dynamic>>[];
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final AppLifecycleListener _life;

  GuestPublic get _peer => widget.call.peer;

  var _lines = <_CallLine>[];
  RemoteTrack? _video;
  RemoteTrack? _audio;
  final _paused = <String>{};
  MediaStream? _stream;
  var _micOn = false;
  var _camOn = false;
  var _front = true;
  var _peerHere = false;
  var _state = SessionState.idle;
  var _seconds = 0;
  var _typing = false;
  Timer? _ticker;
  Timer? _away;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _focus.addListener(() {
      if (!_focus.hasFocus && mounted && _typing) setState(() => _typing = false);
    });
    _life = AppLifecycleListener(onResume: _sync);
    final c = _client;
    _subs.addAll([
      c.onConnectionStateChanged.listen((s) {
        setState(() => _state = s.state);
        _sync();
      }),
      c.onClosed.listen((reason) {
        if (reason != ClosedReason.left) widget.onPeerLeft();
      }),
      c.onTrack.listen((t) {
        setState(() {
          if (t.source == 'camera') _video = t;
          if (t.source == 'mic') _audio = t;
        });
      }),
      c.onTrackEnded.listen((e) {
        setState(() {
          if (_video?.producerId == e.producerId) {
            _video = null;
            _paused.remove('video');
          }
          if (_audio?.producerId == e.producerId) {
            _audio = null;
            _paused.remove('audio');
          }
        });
      }),
      c.onTrackMuted.listen((e) {
        if (e.identity != _peer.id) return;
        setState(() {
          if (e.paused) {
            _paused.add(e.kind);
          } else {
            _paused.remove(e.kind);
          }
        });
      }),
      c.onLocalStreamChanged.listen((_) => _sync()),
      // A drop may be a network blip: their SDK reconnects. Give it time, as VoltKit's call guide does, so a peer whose
      // app was killed does not leave this side waiting forever.
      c.onParticipantLeft.listen((e) {
        if (e.identity != _peer.id) return;
        setState(() => _setPeerHere(false));
        if (e.reason == 'disconnected' || e.reason == 'presence-lost') {
          _away?.cancel();
          _away = Timer(_peerAway, widget.onPeerLeft);
        } else {
          widget.onPeerLeft();
        }
      }),
      c.onParticipantJoined.listen((e) {
        if (e.identity != _peer.id) return;
        _away?.cancel();
        setState(() => _setPeerHere(true));
      }),
      c.onMessage.listen((m) {
        final text = m.text;
        if (m.type != 'text' || text == null || text.isEmpty) return;
        setState(() {
          _lines = [_CallLine(m.id, m.from == widget.call.peer.id ? false : true, text), ..._lines];
          if (_lines.length > 40) _lines = _lines.sublist(0, 40);
        });
      }),
    ]);
    unawaited(_join());
  }

  void _setPeerHere(bool here) {
    _peerHere = here;
    _ticker?.cancel();
    _ticker = here
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _seconds++);
          })
        : null;
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      _stream = _client.localStream;
      _micOn = _client.micEnabled;
      _camOn = _client.camEnabled;
    });
  }

  Future<void> _join() async {
    try {
      await _client.connect();
      if (!mounted) return;
      if (_client.participants.any((p) => p.identity == _peer.id)) setState(() => _setPeerHere(true));
      unawaited(CallService.start(title: 'VoltKit Live call', text: 'Tap to return to the call', leaveLabel: 'End call', onLeave: widget.onStop));
      await _client.publish(video: const VideoPublishOptions(quality: VideoQuality.p720));
      await _client.setSpeakerphoneOn(true);
      _sync();
    } on RpcError catch (err) {
      if (err.code == 'source-already-published' || err.code == 'closed' || err.code == 'unpublished') return;
      toast(mediaProblem(err).text, ToastKind.error);
    } catch (err) {
      final problem = mediaProblem(err);
      toast(problem.text, ToastKind.error);
      if (problem.openSettings) unawaited(openAppSettings());
    }
  }

  void _send() {
    final body = _text.text.trim();
    if (body.isNotEmpty) {
      _client.sendMessage(body).catchError((Object _) {
        toast('Your message was not sent.', ToastKind.error);
        return (id: '', ts: 0);
      });
    }
    _text.clear();
    setState(() => _typing = false);
  }

  Future<void> _block(Session session) async {
    try {
      await api.block(_peer.id);
      await session.refresh();
      toast('${_peer.name} is blocked. You will not be matched again.', ToastKind.success);
      widget.onNext();
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  void _safety() {
    final session = SessionScope.read(context);
    showSheet<void>(
      context,
      title: 'Safety',
      id: 'call-safety',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetRow(
            id: 'call-report',
            icon: Ion.flagOutline,
            label: 'Report ${_peer.name}',
            onTap: () {
              Navigator.pop(sheet);
              unawaited(showReportSheet(context, id: _peer.id, name: _peer.name));
            },
          ),
          SheetRow(
            id: 'call-block',
            icon: Ion.banOutline,
            danger: true,
            label: 'Block ${_peer.name}',
            hint: 'You will not be matched again',
            onTap: () {
              Navigator.pop(sheet);
              unawaited(_block(session));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // force-muted never reaches here in a call, and a failed switch leaves the button as it was.
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _away?.cancel();
    _life.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(CallService.stop());
    unawaited(_client.close());
    unawaited(WakelockPlus.disable());
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final insets = media.padding;
    final keyboard = media.viewInsets.bottom;
    final video = _video != null && !_paused.contains('video') ? _video : null;
    final remoteMicOff = _audio != null && _paused.contains('audio');
    final camera = _camOn && (_stream?.getVideoTracks().isNotEmpty ?? false) ? _stream : null;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null)
            Semantics(identifier: 'remote-video', child: RemoteVideo(key: ValueKey(video.producerId), client: _client, track: video))
          else
            Backdrop(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Avatar(avatar: _peer.avatar, frame: _peer.frame, size: 120),
                  const SizedBox(height: 40),
                  T(_peerHere ? '${_peer.name} has their camera off' : 'Connecting to ${_peer.name}…', variant: V.heading),
                ],
              ),
            ),
          if (camera != null)
            Positioned(
              right: 12,
              top: insets.top + 64,
              width: 104,
              height: 150,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: C.plum,
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: C.white, width: 1.5),
                ),
                child: LocalVideo(stream: camera, mirror: _front),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 130,
            child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: vertical(const [Color(0xBF050309), Color(0x00050309)])))),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: insets.top + 8,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 3, right: 14, top: 3, bottom: 3),
                  decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(R.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Avatar(avatar: _peer.avatar, size: 34),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          T(_peer.name, variant: V.small),
                          T('${remoteMicOff ? 'Muted · ' : ''}${clock(_seconds)}', variant: V.tiny, color: C.textDim),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconBtn(id: 'call-menu', size: 38, icon: Ion.shieldHalf, label: 'Safety', onTap: _safety),
              ],
            ),
          ),
          if (_state == SessionState.reconnecting)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(R.pill)),
                child: const T('Reconnecting…', variant: V.small),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              children: [
                Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: vertical(G.scrimBottom))))),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 36, 12, (keyboard > 0 ? keyboard : insets.bottom) + 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: Semantics(
                          identifier: 'call-chat',
                          child: ListView.separated(
                            reverse: true,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _lines.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final line = _lines[i];
                              return Align(
                                alignment: line.mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: media.size.width * 0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: line.mine ? const Color(0xB88B5CF6) : const Color(0x80000000),
                                    borderRadius: BorderRadius.circular(R.md),
                                  ),
                                  child: T('${line.mine ? '' : '${_peer.name}: '}${line.text}', variant: V.small),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_typing)
                        Row(
                          children: [
                            Expanded(
                              child: Field(
                                id: 'call-input',
                                controller: _text,
                                focusNode: _focus,
                                autofocus: true,
                                hint: 'Message ${_peer.name}',
                                maxLength: 280,
                                height: 44,
                                radius: R.pill,
                                fontSize: 15,
                                weight: FontWeight.w400,
                                fill: const Color(0x24FFFFFF),
                                action: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconBtn(icon: Ion.send, size: 42, active: true, label: 'Send', onTap: _send),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconBtn(id: 'call-mic', size: 50, icon: _micOn ? Ion.mic : Ion.micOff, danger: !_micOn, label: _micOn ? 'Mute' : 'Unmute', onTap: () => unawaited(_quiet(() => _client.setMicEnabled(!_client.micEnabled)))),
                            IconBtn(id: 'call-cam', size: 50, icon: _camOn ? Ion.videocam : Ion.videocamOff, danger: !_camOn, label: _camOn ? 'Camera off' : 'Camera on', onTap: () => unawaited(_quiet(() => _client.setCamEnabled(!_client.camEnabled)))),
                            IconBtn(
                              id: 'call-flip',
                              size: 50,
                              icon: Ion.cameraReverse,
                              label: 'Flip camera',
                              onTap: () => unawaited(_quiet(() async {
                                final front = await _client.switchCamera();
                                if (mounted) setState(() => _front = front);
                              })),
                            ),
                            IconBtn(id: 'call-chat-open', size: 50, icon: Ion.chatbubbleEllipses, label: 'Send a message', onTap: () => setState(() => _typing = true)),
                            IconBtn(id: 'call-next', size: 50, icon: Ion.playSkipForward, active: true, label: 'Next person', onTap: widget.onNext),
                            IconBtn(id: 'call-end', size: 50, icon: Ion.call, danger: true, label: 'End call', turns: 135 / 360, onTap: widget.onStop),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Phase { searching, call, ended }

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  var _phase = _Phase.searching;
  MatchFound? _call;
  String? _lastPeer;
  var _waiting = 0;
  final _off = <void Function()>[];

  @override
  void initState() {
    super.initState();
    _off.addAll([
      liveSocket.on('match:found', (payload) {
        if (!mounted) return;
        setState(() {
          _call = MatchFound.fromJson((payload as Map).cast<String, dynamic>());
          _phase = _Phase.call;
        });
      }),
      liveSocket.on('match:waiting', (payload) {
        if (mounted) setState(() => _waiting = ((payload as Map)['waiting'] as num?)?.toInt() ?? 0);
      }),
      liveSocket.on('match:ended', (payload) {
        if (!mounted || (payload as Map)['callId'] != _call?.callId) return;
        setState(() {
          _lastPeer = _call?.peer.name;
          _call = null;
          _phase = _Phase.ended;
        });
      }),
      liveSocket.on('match:error', (payload) {
        toast((payload as Map)['message'] as String? ?? 'Matching failed.', ToastKind.error);
        if (mounted) Navigator.of(context).pop();
      }),
    ]);
    // After the first frame: the consent sheet needs the route to be in place.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = Navigator.of(context);
      final yes = await askMediaConsent('video');
      if (!mounted) return;
      if (yes) {
        _search();
      } else {
        navigator.pop();
      }
    });
  }

  void _search() {
    setState(() {
      _phase = _Phase.searching;
      _call = null;
    });
    liveSocket.emit('match:join');
  }

  void _hangUp() {
    final current = _call;
    if (current != null) liveSocket.emit('match:end', {'callId': current.callId});
    setState(() => _call = null);
  }

  void _peerLeft() {
    if (!mounted) return;
    _lastPeer = _call?.peer.name;
    _hangUp();
    setState(() => _phase = _Phase.ended);
  }

  void _next() {
    _hangUp();
    _search();
  }

  void _stop() {
    _hangUp();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final off in _off) {
      off();
    }
    liveSocket.emit('match:leave');
    final current = _call;
    if (current != null) liveSocket.emit('match:end', {'callId': current.callId});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: call != null
          // One client per call: a closed session stays closed.
          ? _CallView(key: ValueKey(call.callId), call: call, onNext: _next, onStop: _stop, onPeerLeft: _peerLeft)
          : Backdrop(
              child: Padding(
                padding: EdgeInsets.only(top: insets.top + 8, bottom: insets.bottom + 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconBtn(id: 'match-close', size: 40, icon: Ion.close, label: 'Close', onTap: () => Navigator.of(context).pop()),
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_phase == _Phase.searching) const _Radar(),
                          Container(
                            width: 104,
                            height: 104,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: vertical(G.match)),
                            child: const Icon(Ion.videocam, size: 38, color: C.white),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: _phase == _Phase.searching
                          ? Column(
                              children: gapped(8, [
                                const T('Finding someone…', id: 'match-status', variant: V.title),
                                T(
                                  _waiting > 1 ? '$_waiting people are looking right now' : 'You will be connected as soon as someone else joins',
                                  color: C.textDim,
                                  align: TextAlign.center,
                                ),
                              ]),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(_lastPeer != null ? '$_lastPeer left' : 'Call ended', id: 'match-status', variant: V.title, align: TextAlign.center),
                                const SizedBox(height: 20),
                                GradientButton(id: 'match-again', label: 'Find someone new', icon: Ion.shuffle, colors: G.match, onTap: _search),
                                const SizedBox(height: 8),
                                GhostButton(label: 'Back to home', onTap: () => Navigator.of(context).pop()),
                              ],
                            ),
                    ),
                    const PoweredBy(),
                  ],
                ),
              ),
            ),
    );
  }
}
