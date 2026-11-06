import 'package:voltkit_rtc/voltkit_rtc.dart';

String closedText(ClosedReason reason) => switch (reason) {
      ClosedReason.left => 'You left the room.',
      ClosedReason.kicked => 'You were removed from this room.',
      ClosedReason.roomClosed => 'This room has ended.',
      ClosedReason.replaced => 'You joined this room from another device.',
      ClosedReason.gaveUp => 'The connection was lost.',
    };

({String text, bool canRetry}) joinProblem(Object err) {
  final code = err is RpcError ? err.code : '';
  return switch (code) {
    'bad-token' || 'no-token' => (text: 'Your session expired. Join again.', canRetry: true),
    'room-ended' || 'no-room' => (text: 'This room has ended.', canRetry: false),
    'kicked' => (text: 'You were removed from this room.', canRetry: false),
    'quota-exhausted' || 'daily-limit-reached' || 'monthly-limit-reached' || 'tenant-suspended' || 'billing-unavailable' =>
      (text: 'Live rooms are unavailable right now.', canRetry: false),
    'participant-quota' || 'no-capacity' => (text: 'This room is full right now. Try again in a moment.', canRetry: true),
    _ => (text: 'Could not connect. Check your connection and try again.', canRetry: !isTerminalError(code)),
  };
}

/// Words for a failed action in a room. Never shows the service's raw message.
String actionProblem(Object err) {
  final code = err is RpcError ? err.code : '';
  return switch (code) {
    'forbidden' => 'You do not have permission to do that.',
    'no-participant' => 'That person has left.',
    'slot-taken' => 'Someone just took that seat.',
    'slot-blocked' => 'That seat is locked.',
    'slot-occupied' => 'Someone is sitting there.',
    'chat-muted' => 'You have been muted in this chat.',
    'rate-limited' => 'Slow down a little.',
    'force-muted' => 'The host has this switched off.',
    'stage-full' => 'The stage is full.',
    'not-connected' || 'disconnected' => 'Reconnecting. Try again in a moment.',
    _ => 'That did not work. Try again.',
  };
}

/// publish() throws a String from flutter_webrtc when the system refuses the camera or microphone.
({String text, bool openSettings}) mediaProblem(Object err) {
  final text = err.toString();
  if (text.contains('NotAllowedError') || text.contains('Permission')) {
    return (text: 'Allow the camera and microphone in Settings to go on air.', openSettings: true);
  }
  if (err is String || err is RpcError && err.code == 'media-unavailable') {
    return (text: 'The camera or microphone could not start. Another app may be using it.', openSettings: false);
  }
  return (text: 'Could not start the camera and microphone.', openSettings: false);
}
