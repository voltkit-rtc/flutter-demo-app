import 'package:voltkit_rtc/voltkit_rtc.dart' show Role;

/// What each role may do to whom, as VoltKit enforces it. The service refuses anything else, so this only decides
/// which buttons to show: a button that always fails is worse than no button.
///
/// host        all of it, on anyone but themselves
/// moderator   on viewers only: mute in chat, remove. Handles raised hands. Grants nothing.
/// cohost      publishes; no powers over others
/// viewer      watches
bool canPublish(Role role) => role == Role.host || role == Role.cohost;
bool canModerate(Role role) => role == Role.host || role == Role.moderator;

enum MemberAction {
  inviteSeat,
  removeSeat,
  forceMuteMic,
  releaseMic,
  forceMuteCam,
  releaseCam,
  muteChat,
  unmuteChat,
  makeModerator,
  removeModerator,
  declineHand,
  removeFromRoom,
}

class MemberState {
  const MemberState({
    this.role = Role.viewer,
    this.isSelf = false,
    this.seated = false,
    this.handRaised = false,
    this.micLocked = false,
    this.camLocked = false,
    this.chatMuted = false,
  });

  final Role role;
  final bool isSelf;
  final bool seated;
  final bool handRaised;
  final bool micLocked;
  final bool camLocked;
  final bool chatMuted;
}

List<MemberAction> memberActions(Role actor, MemberState target, bool roomHasVideo) {
  if (target.isSelf || target.role == Role.host) return const [];

  if (actor == Role.host) {
    return [
      if (target.role == Role.cohost) ...[
        MemberAction.removeSeat,
        target.micLocked ? MemberAction.releaseMic : MemberAction.forceMuteMic,
        if (roomHasVideo) target.camLocked ? MemberAction.releaseCam : MemberAction.forceMuteCam,
      ] else if (target.role == Role.viewer)
        MemberAction.inviteSeat,
      if (target.handRaised) MemberAction.declineHand,
      target.chatMuted ? MemberAction.unmuteChat : MemberAction.muteChat,
      if (target.role == Role.viewer) MemberAction.makeModerator,
      if (target.role == Role.moderator) MemberAction.removeModerator,
      MemberAction.removeFromRoom,
    ];
  }

  if (actor == Role.moderator && target.role == Role.viewer) {
    return [
      if (target.handRaised) MemberAction.declineHand,
      target.chatMuted ? MemberAction.unmuteChat : MemberAction.muteChat,
      MemberAction.removeFromRoom,
    ];
  }
  return const [];
}

enum SeatAction { take, request, leave, lock, unlock, invite }

List<SeatAction> seatActions(Role role, {required bool empty, required bool locked, required bool mine, required bool iAmSeated}) {
  if (mine) return const [SeatAction.leave];
  if (role == Role.host) {
    if (locked) return const [SeatAction.unlock];
    return empty ? const [SeatAction.invite, SeatAction.lock] : const [];
  }
  if (locked || !empty || iAmSeated) return const [];
  return role == Role.viewer ? const [SeatAction.request] : const [];
}
