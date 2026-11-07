import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../api/client.dart';
import '../types.dart';
import '../util/toast.dart';
import 'call_service.dart';
import 'consent.dart';
import 'errors.dart';
import 'permissions.dart';
import 'seats.dart';

class Member {
  const Member({
    required this.identity,
    required this.name,
    required this.avatar,
    required this.frame,
    required this.role,
    required this.handRaised,
    required this.wantedSeat,
    required this.micLocked,
    required this.camLocked,
    required this.seat,
  });

  final String identity;
  final String name;
  final String? avatar;
  final Frame frame;
  final Role role;
  final bool handRaised;
  final String? wantedSeat;
  final bool micLocked;
  final bool camLocked;
  final String? seat;
}

/// How many seats there are besides the host. A video room counts the host's own card in `seats`.
int seatCount(Room room) => room.isVideo ? room.seats - 1 : room.seats;

/// The heart of a room: one VoltKit session and all its logic, so widgets only draw state and call the methods here.
/// Roles, seats and moderation are enforced by the service; the host's client is the one that says yes to a seat,
/// because only a host may promote.
class RoomEngine extends ChangeNotifier {
  RoomEngine({required this.room, required this.me, required Credentials credentials, required this.onClosed, required this.onFailed})
      : _credentials = credentials,
        layout = room.layout,
        seatMode = room.seatMode,
        roomCoins = room.giftCoins,
        isHost = room.host.id == me.id,
        seats = seatCount(room),
        // Everyone may be asked on stage, and Android cannot change the audio mode inside a session, so viewers use
        // the call mode too. The camera stops in the background, as phones require, and comes back with the app.
        client = StreamClient(
          wsUrl: credentials.wsUrl,
          token: credentials.token,
          audioMode: AudioMode.communication,
          pauseCameraInBackground: true,
        ) {
    _wantOnAir = isHost;
    _wire();
    _life = AppLifecycleListener(onResume: _syncLocal);
  }

  final Room room;
  final GuestPublic me;
  final StreamClient client;
  final void Function(ClosedReason reason) onClosed;
  final void Function(Object error) onFailed;
  final Credentials _credentials;
  final bool isHost;
  final int seats;

  late final AppLifecycleListener _life;
  final _subs = <StreamSubscription<dynamic>>[];
  var _disposed = false;

  SessionState state = SessionState.idle;
  Claims claims = {};
  Set<String> locked = {};
  RoomLayout layout;
  SeatMode seatMode;
  int roomCoins;
  Set<String> chatMuted = {};
  String? invitedTo;
  bool iMutedInChat = false;
  bool walletLow = false;
  NetworkQuality? network;
  bool speakerphone = true;
  List<Member> members = const [];
  Map<String, Member> memberById = const {};

  // Local media, read back from the client after anything that may change it.
  MediaStream? localStream;
  bool publishing = false;
  bool micEnabled = false;
  bool camEnabled = false;
  bool frontCamera = true;

  final videoById = <String, RemoteTrack>{};
  final _audioById = <String, RemoteTrack>{};

  /// Producer ids this viewer's connection cannot carry right now.
  final held = ValueNotifier<Set<String>>({});

  /// Who is speaking. Apart from everything else, because it changes several times a second.
  final speaking = ValueNotifier<Set<String>>({});

  /// A viewer's seat invitations, remembered on the host's side so only someone actually invited skips the queue.
  final _invites = <String, String>{};

  // What this person means to do, kept apart from whether they are publishing. Going on air spans a role change and
  // sometimes a reconnect, in either order, so _checkOnAir compares the two.
  bool _wantOnAir = false;
  bool _publishingNow = false;
  Timer? _onAirRetry;
  bool _refreshingToken = false;

  Role get myRole {
    final mine = memberById[me.id];
    if (mine != null) return mine.role;
    return client.joinResult?.role ?? _credentials.role;
  }

  String? get mySeat => seatOf(claims, me.id);
  bool get myHand => memberById[me.id]?.handRaised ?? false;
  List<Member> get hands => members.where((m) => m.handRaised && m.role == Role.viewer).toList();

  bool micIsOn(String identity) {
    if (identity == me.id) return publishing && micEnabled;
    final track = _audioById[identity];
    return track != null && !track.paused;
  }

  bool videoIsOn(String identity) {
    final track = videoById[identity];
    return track != null && !track.paused;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _rebuildMembers() {
    final hostId = room.host.id;
    members = [
      for (final p in client.participants)
        () {
          final d = p.metadata ?? const {};
          final isRoomHost = p.identity == hostId;
          return Member(
            identity: p.identity,
            name: d['name'] as String? ?? (isRoomHost ? room.host.name : 'Guest'),
            avatar: d['avatar'] as String? ?? (isRoomHost ? room.host.avatar : null),
            frame: d['frame'] as String? ?? (isRoomHost ? room.host.frame : 'none'),
            role: p.role,
            handRaised: p.handRaised,
            wantedSeat: p.handMetadata?['slot'] is String ? p.handMetadata!['slot'] as String : null,
            micLocked: p.muted,
            camLocked: p.videoBlocked,
            seat: seatOf(claims, p.identity),
          );
        }(),
    ];
    memberById = {for (final m in members) m.identity: m};
    _changed();
  }

  void _syncLocal([Object? _]) {
    localStream = client.localStream;
    publishing = localStream != null;
    micEnabled = client.micEnabled;
    camEnabled = client.camEnabled;
    _changed();
  }

  Map<String, dynamic> get _profile => {'name': me.name, 'avatar': me.avatar, 'frame': me.frame};

  void _wire() {
    final c = client;
    // Wired before connecting: tracks already being published arrive during connect().
    _subs.addAll([
      c.onConnectionStateChanged.listen(_onState),
      c.onClosed.listen((reason) {
        _stopBackground();
        onClosed(reason);
      }),
      c.onTrack.listen(_onTrack),
      c.onTrackEnded.listen(_onTrackEnded),
      // RemoteTrack.paused is current by the time this fires, so there is only redrawing to do.
      c.onTrackMuted.listen((e) {
        if (e.identity == me.id) _syncLocal();
        _changed();
      }),
      c.onLocalStreamChanged.listen(_syncLocal),
      c.onParticipantJoined.listen((_) => _rebuildMembers()),
      c.onParticipantLeft.listen((_) => _rebuildMembers()),
      c.onParticipantUpdated.listen((_) => _rebuildMembers()),
      c.onParticipantMuted.listen((_) => _rebuildMembers()),
      c.onRoleChanged.listen(_onRole),
      c.onHandRaised.listen(_onHand),
      c.onClaimChanged.listen(_onClaim),
      c.onRoomMetadataChanged.listen((meta) => _applySettings(meta)),
      c.onChatMuted.listen(_onChatMuted),
      c.onForceMuted.listen(_onForceMuted),
      c.onMessage.listen(_onMessage),
      c.onWalletLow.listen((w) {
        walletLow = !w.cleared;
        _changed();
      }),
      c.onTokenExpiring.listen((_) => _refreshToken()),
      c.onNetworkQuality.listen((q) {
        network = q;
      }),
      c.onActiveSpeakers.listen((list) => speaking.value = list.toSet()),
      c.onStreamFallback.listen((f) {
        final next = {...held.value};
        if (f.fallback) {
          next.add(f.producerId);
        } else {
          next.remove(f.producerId);
        }
        held.value = next;
      }),
    ]);
  }

  Future<void> start() async {
    try {
      await client.connect(metadata: _profile);
    } catch (err) {
      if (!_disposed) onFailed(err);
      return;
    }
    if (_disposed) return;
    _seed();
    await _startBackground();
    unawaited(setSpeakerphone(true));
    _checkOnAir();
  }

  Future<void> _startBackground() => CallService.start(
        title: room.title,
        text: 'Tap to return to the room',
        leaveLabel: 'Leave',
        onLeave: () => unawaited(client.close()),
      );

  void _stopBackground() => unawaited(CallService.stop());

  // Seats and room settings: read from the join result, then followed through events. The join result is current
  // again by the time a reconnect says connected, with whatever changed while the socket was away.
  void _seed() {
    final joined = client.joinResult;
    if (joined == null) return;
    claims = {for (final c in joined.claims) c.key: SeatClaim(c.identity, c.state)};
    locked = joined.blockedSlots.toSet();
    _applySettings(joined.metadata);
    state = client.connectionState;
    _rebuildMembers();
    _syncLocal();
  }

  void _applySettings(Map<String, dynamic>? meta) {
    final nextLayout = meta?['layout'];
    final nextMode = meta?['seatMode'];
    if (nextLayout is String) layout = nextLayout;
    if (nextMode is String) seatMode = nextMode;
    _changed();
  }

  void _onState(SessionStateChange change) {
    state = change.state;
    if (change.state == SessionState.connected && change.previous == SessionState.reconnecting) _seed();
    _rebuildMembers();
    _syncLocal();
    _checkOnAir();
  }

  void _onTrack(RemoteTrack t) {
    if (t.source == 'camera') videoById[t.identity] = t;
    if (t.source == 'mic') _audioById[t.identity] = t;
    _changed();
  }

  void _onTrackEnded(({String identity, String producerId}) e) {
    if (videoById[e.identity]?.producerId == e.producerId) videoById.remove(e.identity);
    if (_audioById[e.identity]?.producerId == e.producerId) _audioById.remove(e.identity);
    _changed();
  }

  Future<void> _refreshToken() async {
    if (_refreshingToken) return;
    _refreshingToken = true;
    try {
      // A new token for the same session goes to the live connection, with no reconnect.
      final fresh = await api.refreshRoomToken(room.id);
      await client.updateToken(fresh.token);
    } catch (_) {
      // The session keeps its token: only a reconnect after it has expired would need a new one.
    } finally {
      _refreshingToken = false;
    }
  }

  void _checkOnAir() {
    if (state == SessionState.connected && _wantOnAir && canPublish(myRole) && !publishing) unawaited(_goOnAir());
  }

  Future<void> _goOnAir() async {
    if (_publishingNow) return;
    _publishingNow = true;
    try {
      // With no options publish() sends the highest quality the project allows: pick one on purpose.
      if (room.isVideo) {
        await client.publish(video: VideoPublishOptions(quality: room.seats > 6 ? VideoQuality.p480 : VideoQuality.p720));
      } else {
        await client.publish(constraints: const {'audio': true, 'video': false});
      }
      await _startBackground();
      unawaited(setSpeakerphone(speakerphone));
    } on RpcError catch (err) {
      // Cut off by the move to the publishing server: publish again once it has moved.
      if (err.code == 'disconnected') {
        _onAirRetry?.cancel();
        _onAirRetry = Timer(const Duration(milliseconds: 500), _checkOnAir);
      } else if (err.code != 'source-already-published' && err.code != 'closed' && err.code != 'unpublished') {
        await _publishFailed(err);
      }
    } catch (err) {
      await _publishFailed(err);
    } finally {
      _publishingNow = false;
      _syncLocal();
    }
  }

  Future<void> _publishFailed(Object err) async {
    _wantOnAir = false;
    final problem = mediaProblem(err);
    toast(problem.text, ToastKind.error);
    if (problem.openSettings) unawaited(openAppSettings());
    final seat = seatOf(claims, me.id);
    if (seat != null) await client.release(seat).catchError((Object _) {});
  }

  void _onRole(RoleChanged e) {
    _rebuildMembers();
    if (e.identity != me.id) return;
    if (canPublish(e.role)) {
      _wantOnAir = true;
      toast('You are on stage', ToastKind.success);
      _checkOnAir();
    } else {
      _wantOnAir = false;
      toast(e.role == Role.moderator ? 'You are now a moderator' : 'You are back in the audience');
      // A demotion leaves the seat claimed on the service, and an empty card behind it.
      final seat = seatOf(claims, me.id);
      if (seat != null) unawaited(client.release(seat).catchError((Object _) {}));
      _syncLocal();
    }
  }

  /// The host's side of a seat: claim first, so a seat that has gone means nothing else happened.
  Future<void> seatGuest(String identity, Object? wanted) async {
    final seat = pickSeat(wanted, seats, claims, locked);
    if (seat == null) {
      await client.lowerHand(identity: identity).catchError((Object _) {});
      toast('All seats are taken');
      return;
    }
    try {
      await client.claim(seat, identity: identity);
      await client.promote(identity, Role.cohost);
    } catch (err) {
      await client.release(seat).catchError((Object _) {});
      await client.lowerHand(identity: identity).catchError((Object _) {});
      toast(actionProblem(err), ToastKind.error);
    }
  }

  void _onHand(HandRaised e) {
    _rebuildMembers();
    if (e.identity == me.id) {
      if (!e.raised && e.wasDeclined) toast('The host declined your request');
      return;
    }
    if (!e.raised || !isHost) return;
    final invitedSeat = _invites[e.identity];
    if (invitedSeat != null || seatMode == 'open') {
      _invites.remove(e.identity);
      unawaited(seatGuest(e.identity, invitedSeat ?? e.slot));
      return;
    }
    toast('${memberById[e.identity]?.name ?? 'Someone'} is asking for a seat');
  }

  void _onClaim(ClaimChanged e) {
    final holder = claims[e.key]?.identity;
    claims = applyClaim(claims, key: e.key, identity: e.identity, state: e.state);
    if (e.isBlocked || e.reason == 'unblocked') {
      locked = {...locked};
      if (e.isBlocked) {
        locked.add(e.key);
      } else {
        locked.remove(e.key);
      }
    }
    // Someone gave up their seat: back to the audience, which only the host can do for them.
    if (isHost && e.isFree && e.reason == 'released' && holder != null && memberById[holder]?.role == Role.cohost) {
      unawaited(client.promote(holder, Role.viewer).catchError((Object _) {}));
    }
    _rebuildMembers();
  }

  String _whoIs(String identity) => identity == room.host.id ? 'The host' : 'A moderator';

  void _onChatMuted(ChatMuted e) {
    if (e.identity == me.id) {
      iMutedInChat = e.muted;
      toast(e.muted ? '${_whoIs(e.by)} muted you in this chat' : 'You can chat again');
    }
    chatMuted = {...chatMuted};
    if (e.muted) {
      chatMuted.add(e.identity);
    } else {
      chatMuted.remove(e.identity);
    }
    _changed();
  }

  void _onForceMuted(({String by, String kind, bool paused}) e) {
    final what = switch (e.kind) {
      'audio' => 'microphone',
      'video' => 'camera',
      _ => 'camera and microphone',
    };
    toast(e.paused ? '${_whoIs(e.by)} switched off your $what' : 'You can switch your $what back on');
    _syncLocal();
  }

  void _onMessage(ChatMessage m) {
    final total = m.metadata?['roomCoins'];
    if (m.type == 'gift' && total is num) {
      roomCoins = total.toInt();
      _changed();
    }
    if (m.type == 'invite' && m.to == me.id) {
      final slot = m.metadata?['slot'];
      invitedTo = slot is String ? slot : 'any';
      _changed();
    }
  }

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (done != null) toast(done, ToastKind.success);
    } catch (err) {
      toast(actionProblem(err), ToastKind.error);
    }
  }

  // --- actions ---------------------------------------------------------------------------------------------------

  Future<void> toggleMic() async {
    if (!publishing) {
      _wantOnAir = true;
      return _goOnAir();
    }
    await _run(() => client.setMicEnabled(!client.micEnabled));
    _syncLocal();
  }

  Future<void> toggleCam() async {
    await _run(() => client.setCamEnabled(!client.camEnabled));
    _syncLocal();
  }

  Future<void> flipCamera() => _run(() async {
        frontCamera = await client.switchCamera();
        _changed();
      });

  Future<void> requestSeat([String? slot]) async {
    if (!await askMediaConsent(room.type)) return;
    await _run(() => client.raiseHand(metadata: {'requestRole': 'cohost', 'slot': ?slot}));
  }

  Future<void> cancelRequest() => _run(() => client.lowerHand());

  Future<void> leaveSeat() async {
    _wantOnAir = false;
    final seat = mySeat;
    await _run(() async {
      await client.unpublish();
      if (seat != null) await client.release(seat);
    });
    _syncLocal();
  }

  Future<void> acceptHand(String identity, String? wanted) => seatGuest(identity, wanted);
  Future<void> declineHand(String identity) => _run(() => client.lowerHand(identity: identity));

  void inviteToSeat(String identity, [String? slot]) {
    final seat = slot ?? firstFreeSeat(seats, claims, locked);
    if (seat == null) return toast('All seats are taken');
    // Remembered here, so only someone actually invited skips the queue.
    _invites[identity] = seat;
    unawaited(_run(() => client.sendMessage('', type: 'invite', to: identity, metadata: {'slot': seat}), 'Invitation sent'));
  }

  Future<void> acceptInvite() async {
    final slot = invitedTo == 'any' ? null : invitedTo;
    invitedTo = null;
    _changed();
    if (!await askMediaConsent(room.type)) return;
    await _run(() => client.raiseHand(metadata: {'requestRole': 'cohost', 'slot': ?slot, 'invited': true}));
  }

  void declineInvite() {
    invitedTo = null;
    _changed();
  }

  Future<void> removeFromSeat(String identity) => _run(() async {
        final seat = seatOf(claims, identity);
        if (seat != null) await client.release(seat);
        await client.promote(identity, Role.viewer);
      }, 'Moved to the audience');

  Future<void> lockSeat(String key) => _run(() => client.blockSlot(key));
  Future<void> unlockSeat(String key) => _run(() => client.unblockSlot(key));

  Future<void> forceMic(String identity, bool off) =>
      _run(() => client.forceMute(identity, kind: 'audio', paused: off), off ? 'Microphone off' : 'Released');
  Future<void> forceCam(String identity, bool off) =>
      _run(() => client.forceMute(identity, kind: 'video', paused: off), off ? 'Camera off' : 'Released');

  Future<void> muteAll() => _run(() async {
        final onStage = client.participants.where((p) => p.role == Role.cohost && !p.muted);
        await Future.wait(onStage.map((p) => client.forceMute(p.identity, kind: 'audio', paused: true)));
      }, 'Everyone on stage is muted');

  Future<void> setChatMute(String identity, bool muted) =>
      _run(() => client.muteChat(identity, muted: muted), muted ? 'Muted in chat' : 'Can chat again');

  Future<void> makeModerator(String identity) => _run(() => client.promote(identity, Role.moderator), 'Now a moderator');
  Future<void> removeModerator(String identity) => _run(() => client.promote(identity, Role.viewer), 'No longer a moderator');

  Future<void> removeFromRoom(String identity) => _run(() async {
        // Kick stops the tokens minted so far. The ban stops the backend minting another, so it goes first.
        await api.banFromRoom(room.id, identity);
        await client.kick(identity, 'Removed from the room');
      }, 'Removed from the room');

  Future<void> setRoomLayout(RoomLayout next) => _run(() async {
        await client.setRoomMetadata({'layout': next});
      });
  Future<void> setRoomSeatMode(SeatMode next) => _run(() async {
        await client.setRoomMetadata({'seatMode': next});
      });

  Future<void> endRoom() => _run(() => api.endRoom(room.id));

  Future<void> setSpeakerphone(bool on) async {
    speakerphone = on;
    try {
      await client.setSpeakerphoneOn(on);
    } catch (_) {
      // A headset keeps the sound; the choice stands for when it goes.
    }
    _changed();
  }

  /// Whether there is anywhere else to send the sound.
  Future<bool> hasOtherOutputs() async {
    try {
      return (await client.listDevices(DeviceKind.audiooutput)).length > 1;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _onAirRetry?.cancel();
    _life.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    held.dispose();
    speaking.dispose();
    _stopBackground();
    unawaited(client.close());
    super.dispose();
  }
}
