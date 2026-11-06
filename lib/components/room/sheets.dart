import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

import '../../api/client.dart';
import '../../config.dart';
import '../../icons.dart';
import '../../rtc/permissions.dart';
import '../../rtc/room_engine.dart';
import '../../rtc/seats.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../util/toast.dart';
import '../ui.dart';

const _reasons = [
  ('harassment', 'Harassment or hate'),
  ('nudity', 'Nudity or sexual content'),
  ('violence', 'Violence or threats'),
  ('underage', 'Appears to be under 18'),
  ('spam', 'Spam or scam'),
  ('other', 'Something else'),
];

Future<void> showReportSheet(BuildContext context, {required String id, required String name, String? roomId}) => showSheet<void>(
      context,
      title: 'Report $name',
      id: 'report-sheet',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (reason, label) in _reasons)
            SheetRow(
              id: 'report-$reason',
              icon: Ion.flagOutline,
              label: label,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await api.report(id, reason, roomId);
                  toast('Thanks. We have your report.', ToastKind.success);
                } on ApiError catch (err) {
                  toast(err.message, ToastKind.error);
                }
              },
            ),
        ],
      ),
    );

const _actionLook = <MemberAction, (IconData, String, String, bool)>{
  MemberAction.inviteSeat: (Ion.personAddOutline, 'invite-seat', 'Invite to a seat', false),
  MemberAction.removeSeat: (Ion.arrowDownCircleOutline, 'remove-seat', 'Move to the audience', false),
  MemberAction.forceMuteMic: (Ion.micOffOutline, 'force-mute-mic', 'Switch off their microphone', false),
  MemberAction.releaseMic: (Ion.micOutline, 'release-mic', 'Release their microphone', false),
  MemberAction.forceMuteCam: (Ion.videocamOffOutline, 'force-mute-cam', 'Switch off their camera', false),
  MemberAction.releaseCam: (Ion.videocamOutline, 'release-cam', 'Release their camera', false),
  MemberAction.muteChat: (Ion.chatboxEllipsesOutline, 'mute-chat', 'Mute in chat', false),
  MemberAction.unmuteChat: (Ion.chatboxOutline, 'unmute-chat', 'Allow in chat', false),
  MemberAction.makeModerator: (Ion.shieldCheckmarkOutline, 'make-moderator', 'Make moderator', false),
  MemberAction.removeModerator: (Ion.shieldOutline, 'remove-moderator', 'Remove as moderator', false),
  MemberAction.declineHand: (Ion.handLeftOutline, 'decline-hand', 'Decline their request', false),
  MemberAction.removeFromRoom: (Ion.exitOutline, 'remove-from-room', 'Remove from the room', true),
};

Future<void> showMemberSheet(
  BuildContext context, {
  required RoomEngine engine,
  required String identity,
  String? messageId,
  required void Function(String identity) onGift,
  required void Function(String id, String name) onReport,
  required void Function(String identity) onMessage,
}) =>
    showSheet<void>(
      context,
      id: 'member-sheet',
      builder: (_) => ListenableBuilder(
        listenable: engine,
        builder: (context, _) => _MemberSheet(engine: engine, identity: identity, messageId: messageId, onGift: onGift, onReport: onReport, onMessage: onMessage),
      ),
    );

class _MemberSheet extends StatelessWidget {
  const _MemberSheet({required this.engine, required this.identity, required this.onGift, required this.onReport, required this.onMessage, this.messageId});

  final RoomEngine engine;
  final String identity;
  final String? messageId;
  final void Function(String identity) onGift;
  final void Function(String id, String name) onReport;
  final void Function(String identity) onMessage;

  void _act(MemberAction action) {
    final id = identity;
    switch (action) {
      case MemberAction.inviteSeat:
        engine.inviteToSeat(id);
      case MemberAction.removeSeat:
        unawaited(engine.removeFromSeat(id));
      case MemberAction.forceMuteMic:
        unawaited(engine.forceMic(id, true));
      case MemberAction.releaseMic:
        unawaited(engine.forceMic(id, false));
      case MemberAction.forceMuteCam:
        unawaited(engine.forceCam(id, true));
      case MemberAction.releaseCam:
        unawaited(engine.forceCam(id, false));
      case MemberAction.muteChat:
        unawaited(engine.setChatMute(id, true));
      case MemberAction.unmuteChat:
        unawaited(engine.setChatMute(id, false));
      case MemberAction.makeModerator:
        unawaited(engine.makeModerator(id));
      case MemberAction.removeModerator:
        unawaited(engine.removeModerator(id));
      case MemberAction.declineHand:
        unawaited(engine.declineHand(id));
      case MemberAction.removeFromRoom:
        unawaited(engine.removeFromRoom(id));
    }
  }

  Future<void> _toggleBlock(Session session, bool blocked, String name) async {
    try {
      if (blocked) {
        await api.unblock(identity);
      } else {
        await api.block(identity);
      }
      await session.refresh();
      toast(blocked ? 'Unblocked' : '$name is blocked', ToastKind.success);
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final member = engine.memberById[identity];
    final name = member?.name ?? 'Guest';
    final mine = identity == engine.me.id;
    final blocked = session.guest.blocked.contains(identity);
    final myRole = engine.myRole;
    final list = member == null
        ? const <MemberAction>[]
        : memberActions(
            myRole,
            MemberState(
              role: member.role,
              isSelf: mine,
              seated: member.seat != null,
              handRaised: member.handRaised,
              micLocked: member.micLocked,
              camLocked: member.camLocked,
              chatMuted: engine.chatMuted.contains(identity),
            ),
            engine.room.isVideo,
          );

    void close(VoidCallback then) {
      Navigator.pop(context);
      then();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 12),
          child: Row(
            children: [
              Avatar(avatar: member?.avatar, frame: member?.frame ?? 'none', size: 52),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('$name${mine ? ' (you)' : ''}', variant: V.heading, lines: 1),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (member != null) RoleBadge(role: member.role.name),
                        if (member?.seat != null) ...[
                          const SizedBox(width: 6),
                          T('Seat ${seatNumber(member!.seat!)}', variant: V.tiny, color: C.textDim),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in list)
                  SheetRow(
                    id: 'action-${_actionLook[a]!.$2}',
                    icon: _actionLook[a]!.$1,
                    label: _actionLook[a]!.$3,
                    danger: _actionLook[a]!.$4,
                    onTap: () => close(() => _act(a)),
                  ),
                if (messageId != null && (canModerate(myRole) || mine))
                  SheetRow(
                    id: 'action-delete-message',
                    icon: Ion.trashOutline,
                    label: 'Delete this message',
                    onTap: () => close(() {
                      engine.client.deleteMessage(messageId!).catchError((Object _) => toast('Could not delete that message.', ToastKind.error));
                    }),
                  ),
                SheetRow(
                  id: 'action-gift',
                  icon: Ion.giftOutline,
                  label: mine ? 'Send yourself a gift' : 'Send a gift',
                  gold: true,
                  onTap: () => close(() => onGift(identity)),
                ),
                if (!mine) ...[
                  SheetRow(
                    id: 'action-message',
                    icon: Ion.chatbubbleEllipsesOutline,
                    label: 'Send a message',
                    onTap: () => close(() => onMessage(identity)),
                  ),
                  SheetRow(
                    id: 'action-report',
                    icon: Ion.flagOutline,
                    label: 'Report',
                    onTap: () => close(() => onReport(identity, name)),
                  ),
                  SheetRow(
                    id: 'action-block',
                    icon: Ion.banOutline,
                    label: blocked ? 'Unblock' : 'Block',
                    danger: !blocked,
                    onTap: () => close(() => unawaited(_toggleBlock(session, blocked, name))),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showSeatSheet(BuildContext context, RoomEngine engine, String seat) => showSheet<void>(
      context,
      title: 'Seat No.${seatNumber(seat)}',
      id: 'seat-sheet',
      builder: (_) => ListenableBuilder(
        listenable: engine,
        builder: (context, _) {
          final claim = engine.claims[seat];
          final locked = engine.locked.contains(seat);
          final list = seatActions(engine.myRole, empty: claim == null, locked: locked, mine: claim?.identity == engine.me.id, iAmSeated: engine.mySeat != null);
          final open = engine.seatMode == 'open';

          void close(VoidCallback then) {
            Navigator.pop(context);
            then();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.contains(SeatAction.request))
                SheetRow(
                  id: 'seat-request',
                  icon: Ion.handLeftOutline,
                  label: open ? 'Take this seat' : 'Ask for this seat',
                  hint: open ? 'You go on stage straight away' : 'The host decides',
                  onTap: () => close(() => unawaited(engine.requestSeat(seat))),
                ),
              if (list.contains(SeatAction.leave))
                SheetRow(id: 'seat-leave', icon: Ion.exitOutline, label: 'Leave this seat', onTap: () => close(() => unawaited(engine.leaveSeat()))),
              if (list.contains(SeatAction.lock))
                SheetRow(id: 'seat-lock', icon: Ion.lockClosedOutline, label: 'Lock this seat', onTap: () => close(() => unawaited(engine.lockSeat(seat)))),
              if (list.contains(SeatAction.unlock))
                SheetRow(id: 'seat-unlock', icon: Ion.lockOpenOutline, label: 'Unlock this seat', onTap: () => close(() => unawaited(engine.unlockSeat(seat)))),
              if (list.contains(SeatAction.invite))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: T('To fill this seat, tap someone in the audience list and invite them.', variant: V.small, color: C.textFaint),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: T(locked ? 'The host has locked this seat.' : 'This seat is not available.', color: C.textDim),
                ),
            ],
          );
        },
      ),
    );

const _roleOrder = {Role.host: 0, Role.moderator: 1, Role.cohost: 2, Role.viewer: 3};

Future<void> showPeopleSheet(BuildContext context, RoomEngine engine, void Function(String identity) onMember) => showSheet<void>(
      context,
      id: 'people-sheet',
      builder: (_) => ListenableBuilder(
        listenable: engine,
        builder: (context, _) {
          final members = engine.members;
          final hands = engine.hands;
          final canAccept = engine.myRole == Role.host;
          final canDecline = canModerate(engine.myRole);
          final sorted = [...members]..sort((a, b) => _roleOrder[a.role]!.compareTo(_roleOrder[b.role]!));
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T('In the room (${members.length})', variant: V.heading),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hands.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: T('ASKING FOR A SEAT', variant: V.tiny, color: C.textFaint, spacing: 1),
                        ),
                        for (final m in hands)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Avatar(avatar: m.avatar, size: 38),
                                const SizedBox(width: 10),
                                Expanded(child: T(m.name, variant: V.medium, lines: 1)),
                                if (canDecline) ...[
                                  const SizedBox(width: 10),
                                  Tap(
                                    id: 'decline-${m.identity}',
                                    label: 'Decline ${m.name}',
                                    onTap: () => unawaited(engine.declineHand(m.identity)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(color: C.glassStrong, borderRadius: BorderRadius.circular(R.pill)),
                                      child: const T('Decline', variant: V.tiny),
                                    ),
                                  ),
                                ],
                                if (canAccept) ...[
                                  const SizedBox(width: 10),
                                  Tap(
                                    id: 'accept-${m.identity}',
                                    label: 'Accept ${m.name}',
                                    onTap: () => unawaited(engine.acceptHand(m.identity, m.wantedSeat)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(R.pill)),
                                      child: const T('Accept', variant: V.tiny, color: C.ink),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      for (final m in sorted)
                        Tap(
                          id: 'person-${m.identity}',
                          label: m.name,
                          onTap: () {
                            Navigator.pop(context);
                            onMember(m.identity);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Avatar(avatar: m.avatar, size: 38),
                                const SizedBox(width: 10),
                                Expanded(child: T(m.name, variant: V.medium, lines: 1)),
                                const SizedBox(width: 10),
                                RoleBadge(role: m.role.name),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

const _networkWords = {
  NetworkQualityLevel.excellent: 'Excellent',
  NetworkQualityLevel.good: 'Good',
  NetworkQualityLevel.poor: 'Poor',
  NetworkQualityLevel.bad: 'Bad',
};

Future<void> showMoreSheet(
  BuildContext context, {
  required RoomEngine engine,
  required VoidCallback onLeave,
  required VoidCallback onPeople,
  required VoidCallback onReportRoom,
}) async {
  final others = await engine.hasOtherOutputs();
  if (!context.mounted) return;
  await showSheet<void>(
    context,
    title: 'Room',
    id: 'more-sheet',
    builder: (_) => ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final isHost = engine.isHost;
        final network = engine.network;

        void close(VoidCallback then) {
          Navigator.pop(context);
          then();
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetRow(id: 'more-people', icon: Ion.peopleOutline, label: 'People in the room', onTap: () => close(onPeople)),
              if (isHost && engine.room.isVideo)
                SheetRow(
                  id: 'more-layout',
                  icon: Ion.gridOutline,
                  label: engine.layout == 'stage' ? 'Switch to grid layout' : 'Switch to stage layout',
                  hint: 'Everyone in the room sees the change',
                  onTap: () => close(() => unawaited(engine.setRoomLayout(engine.layout == 'stage' ? 'grid' : 'stage'))),
                ),
              if (isHost)
                SheetRow(
                  id: 'more-seat-mode',
                  icon: engine.seatMode == 'open' ? Ion.lockOpenOutline : Ion.handLeftOutline,
                  label: engine.seatMode == 'open' ? 'Require your approval for seats' : 'Let anyone take a seat',
                  onTap: () => close(() => unawaited(engine.setRoomSeatMode(engine.seatMode == 'open' ? 'request' : 'open'))),
                ),
              if (isHost)
                SheetRow(id: 'more-mute-all', icon: Ion.volumeMuteOutline, label: 'Mute everyone on stage', onTap: () => close(() => unawaited(engine.muteAll()))),
              if (engine.mySeat != null)
                SheetRow(id: 'more-leave-seat', icon: Ion.arrowDownCircleOutline, label: 'Leave my seat', onTap: () => close(() => unawaited(engine.leaveSeat()))),
              if (engine.myRole == Role.viewer && engine.myHand)
                SheetRow(icon: Ion.handLeftOutline, label: 'Cancel my request', onTap: () => close(() => unawaited(engine.cancelRequest()))),
              if (others)
                SheetRow(
                  icon: engine.speakerphone ? Ion.volumeHighOutline : Ion.earOutline,
                  label: engine.speakerphone ? 'Use the earpiece' : 'Use the loudspeaker',
                  onTap: () => close(() => unawaited(engine.setSpeakerphone(!engine.speakerphone))),
                ),
              if (network != null)
                SheetRow(
                  icon: Ion.cellularOutline,
                  label: 'Connection: ${_networkWords[network.level]}',
                  hint: network.rttMs != null ? '${network.rttMs} ms round trip' : null,
                  onTap: () => Navigator.pop(context),
                ),
              if (!isHost) SheetRow(id: 'more-report', icon: Ion.flagOutline, label: 'Report this room', onTap: () => close(onReportRoom)),
              SheetRow(
                icon: Ion.flashOutline,
                gold: true,
                label: Voltkit.poweredBy,
                hint: 'A Flutter demo. Build yours at voltkit.in',
                onTap: () => close(() => unawaited(openUrl(Voltkit.site))),
              ),
              SheetRow(id: 'more-leave', icon: Ion.powerOutline, danger: true, label: isHost ? 'End the room' : 'Leave the room', onTap: () => close(onLeave)),
            ],
          ),
        );
      },
    ),
  );
}

Future<bool> showConfirmEnd(BuildContext context, {required bool isHost}) async =>
    await showSheet<bool>(
      context,
      id: 'confirm-end',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T(isHost ? 'End this room?' : 'Leave this room?', variant: V.title),
          const SizedBox(height: 10),
          T(isHost ? 'The room closes for everyone in it.' : 'You can come back while it is live.', color: C.textDim),
          const SizedBox(height: 16),
          GradientButton(id: 'confirm-end-yes', label: isHost ? 'End the room' : 'Leave', colors: G.danger, onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 10),
          GhostButton(label: 'Stay', onTap: () => Navigator.pop(context, false)),
        ],
      ),
    ) ??
    false;

Future<void> showInviteSheet(BuildContext context, RoomEngine engine) async {
  final video = engine.room.isVideo;
  final yes = await showSheet<bool>(
    context,
    id: 'invite-sheet',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const T('The host invited you on stage', variant: V.title),
        const SizedBox(height: 10),
        T(video ? 'Your camera and microphone go live to the room.' : 'Your microphone goes live to the room.', color: C.textDim),
        const SizedBox(height: 16),
        GradientButton(id: 'invite-accept', label: 'Join the stage', onTap: () => Navigator.pop(context, true)),
        const SizedBox(height: 10),
        GhostButton(label: 'No thanks', onTap: () => Navigator.pop(context, false)),
      ],
    ),
  );
  if (yes == true) {
    await engine.acceptInvite();
  } else {
    engine.declineInvite();
  }
}
