import 'package:flutter_test/flutter_test.dart';
import 'package:voltkit_live/rtc/permissions.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart' show Role, RolePermissions;

const roles = [Role.host, Role.cohost, Role.moderator, Role.viewer];

void main() {
  group('who may do what', () {
    test('matches VoltKit: hosts and co-hosts publish, hosts and moderators moderate', () {
      expect(roles.map(canPublish), [true, true, false, false]);
      expect(roles.map(canModerate), [true, false, true, false]);
      // The app's list and the SDK's own must agree.
      for (final r in roles) {
        expect(canPublish(r), r.canPublish);
        expect(canModerate(r), r.canModerate);
      }
    });

    test('gives nobody any action on the host, or on themselves', () {
      for (final actor in roles) {
        expect(memberActions(actor, const MemberState(role: Role.host), true), isEmpty);
        expect(memberActions(actor, const MemberState(isSelf: true), true), isEmpty);
      }
    });

    test('gives co-hosts and viewers no power over anyone', () {
      for (final actor in [Role.cohost, Role.viewer]) {
        expect(memberActions(actor, const MemberState(), true), isEmpty);
        expect(memberActions(actor, const MemberState(role: Role.cohost), true), isEmpty);
      }
    });

    test('gives a host the full set on a co-host', () {
      expect(memberActions(Role.host, const MemberState(role: Role.cohost, seated: true), true), [
        MemberAction.removeSeat,
        MemberAction.forceMuteMic,
        MemberAction.forceMuteCam,
        MemberAction.muteChat,
        MemberAction.removeFromRoom,
      ]);
    });

    test('offers release once something is locked', () {
      final actions = memberActions(Role.host, const MemberState(role: Role.cohost, micLocked: true, camLocked: true, chatMuted: true), true);
      expect(actions, containsAll([MemberAction.releaseMic, MemberAction.releaseCam, MemberAction.unmuteChat]));
      expect(actions, isNot(contains(MemberAction.forceMuteMic)));
    });

    test('offers no camera controls in an audio room', () {
      final actions = memberActions(Role.host, const MemberState(role: Role.cohost), false);
      expect(actions, isNot(contains(MemberAction.forceMuteCam)));
      expect(actions, isNot(contains(MemberAction.releaseCam)));
    });

    test('lets a host raise a viewer to moderator, and take it back', () {
      expect(memberActions(Role.host, const MemberState(), true), contains(MemberAction.makeModerator));
      expect(memberActions(Role.host, const MemberState(role: Role.moderator), true), contains(MemberAction.removeModerator));
    });

    test('keeps moderators to viewers, and away from roles and seats', () {
      expect(memberActions(Role.moderator, const MemberState(handRaised: true), true), [MemberAction.declineHand, MemberAction.muteChat, MemberAction.removeFromRoom]);
      expect(memberActions(Role.moderator, const MemberState(role: Role.cohost), true), isEmpty);
      expect(memberActions(Role.moderator, const MemberState(role: Role.moderator), true), isEmpty);
    });
  });

  group('seats', () {
    List<SeatAction> act(Role role, {bool empty = true, bool locked = false, bool mine = false, bool seated = false}) =>
        seatActions(role, empty: empty, locked: locked, mine: mine, iAmSeated: seated);

    test('lets a viewer ask for an empty seat only', () {
      expect(act(Role.viewer), [SeatAction.request]);
      expect(act(Role.viewer, empty: false), isEmpty);
      expect(act(Role.viewer, locked: true), isEmpty);
    });

    test('lets you leave your own seat', () {
      expect(act(Role.cohost, empty: false, mine: true, seated: true), [SeatAction.leave]);
    });

    test('lets a host lock and unlock', () {
      expect(act(Role.host), [SeatAction.invite, SeatAction.lock]);
      expect(act(Role.host, locked: true), [SeatAction.unlock]);
    });

    test('gives a moderator no seat powers, since they cannot publish', () {
      expect(act(Role.moderator), isEmpty);
    });

    test('does not offer a second seat to someone already seated', () {
      expect(act(Role.cohost, seated: true), isEmpty);
    });
  });
}
