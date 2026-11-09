# Build the features

Seats, roles, moderation, chat, gifts, 1v1 calls and direct messages, the way this app builds them. Read
[Integrate VoltKit into your app](integrate-into-your-app.md) first: everything here runs on the connected `client` from there.

All the room logic is in one class, [`RoomEngine`](../lib/rtc/room_engine.dart). Widgets draw its state and call its methods.

## Roles

| Role | Can |
| --- | --- |
| `host` | Everything: publish, seat people, moderate, end the room |
| `moderator` | On viewers only: mute them in chat, remove them, decline their requests. Cannot seat people |
| `cohost` | Publish. Someone on stage |
| `viewer` | Watch, chat, raise a hand |

The backend picks the role when it mints the token: the room's creator is the host, everyone else joins as a viewer.
[`lib/rtc/permissions.dart`](../lib/rtc/permissions.dart) turns roles into what each person sees in the menus.

## Seats

A seat is a named slot (`seat-1`, `seat-2`, ...). Only a host may promote, so the host's app is the one that says yes.

```dart
// A viewer asks, optionally for one seat:
await client.raiseHand(metadata: {'requestRole': 'cohost', 'slot': 'seat-3'});

// The host's app hears it on onHandRaised, and seats them. Claim first: if the seat has gone, nothing else happened.
try {
  await client.claim('seat-3', identity: viewerId);
  await client.promote(viewerId, Role.cohost);
} catch (_) {
  await client.release('seat-3').catchError((Object _) {});
  await client.lowerHand(identity: viewerId).catchError((Object _) {});
}

// Decline a request, leave a seat, lock one:
await client.lowerHand(identity: viewerId);
await client.release('seat-3');
await client.blockSlot('seat-5'); // unblockSlot to open it again
```

The new co-host's app publishes when `onRoleChanged` names it (see step 7 of the integration guide). Seats are in
`client.joinResult?.claims` after connecting and change on `onClaimChanged`. Moving someone back to the audience is `release` plus
`promote(id, Role.viewer)`: a demotion alone keeps the seat claimed. See [`lib/rtc/seats.dart`](../lib/rtc/seats.dart).

**Invitations** go as a chat message to one person, which their app turns into a prompt:

```dart
await client.sendMessage('', type: 'invite', to: viewerId, metadata: {'slot': 'seat-2'});
```

## Moderation

```dart
await client.forceMute(id, kind: 'audio', paused: true);  // 'video' for the camera; paused: false gives it back
await client.muteChat(id, muted: true);
await client.promote(id, Role.moderator);                 // Role.viewer to take it away

// Removing someone: ban on your backend first, so it mints no new token, then kick.
await api.banFromRoom(roomId, id);                         // POST /v1/rooms/:id/bans on the demo backend
await client.kick(id, 'Removed from the room');
```

The person removed gets `onClosed` with `ClosedReason.kicked`; someone force-muted gets `onForceMuted`.

## Room settings

Room-wide settings live in the room's metadata, so everyone sees a change at once:

```dart
await client.setRoomMetadata({'layout': 'grid'});      // or 'stage'
await client.setRoomMetadata({'seatMode': 'open'});    // or 'request'
client.onRoomMetadataChanged.listen(applySettings);
```

## Speaking, network and weak video

```dart
client.onActiveSpeakers.listen((ids) => speaking.value = ids.toSet()); // draw a ring around each
client.onNetworkQuality.listen((q) => network = q);                      // q.level, q.rttMs
client.onStreamFallback.listen((f) { /* f.fallback: a video paused to save the audio; show "Weak connection" */ });
```

## Room chat

```dart
await client.sendMessage(text, metadata: {'name': me.name, 'avatar': me.avatar});
final history = await client.getMessages(limit: 30); // oldest first
client.onMessage.listen(addLine);                     // your own come back here too
await client.deleteMessage(messageId);                 // yours, or anyone's for a moderator
```

**Hearts** are ephemeral messages: delivered, never stored.

```dart
await client.sendMessage('', type: 'reaction', metadata: const {'emoji': 'heart'}, ephemeral: true);
```

See [`lib/components/room/chat.dart`](../lib/components/room/chat.dart) and [`reactions.dart`](../lib/components/room/reactions.dart).

## Gifts and entrance effects

The app never sends a gift message itself. It asks the backend, which checks and spends the coins, then sends a trusted message into
the room with the server SDK:

```dart
await api.sendGift(roomId, giftId, toIdentity, count); // POST /v1/rooms/:id/gifts on the demo backend
```

Everyone's app hears it on `onMessage` with `type == 'gift'` and plays the animation named in `metadata['svgaUrl']`. Entrance effects
work the same way with `type == 'entrance'`, sent by the backend when someone with a frame joins.
[`lib/gifts/gift_stage.dart`](../lib/gifts/gift_stage.dart) plays them one at a time with
[flutter_svga](https://pub.dev/packages/flutter_svga), falls back to the gift's icon if a file cannot play, and skips one that stalls.
[`lib/gifts/queue.dart`](../lib/gifts/queue.dart) keeps the queue short.

## 1v1 calls

A call is a VoltKit room with two people. The backend's matchmaker pairs people over Socket.IO and sends each phone its own token:

```dart
liveSocket.emit('match:join');
liveSocket.on('match:found', (payload) {
  final call = MatchFound.fromJson((payload as Map).cast<String, dynamic>()); // callId, token, wsUrl, peer
  final client = StreamClient(wsUrl: call.wsUrl, token: call.token, audioMode: AudioMode.communication, pauseCameraInBackground: true);
  // connect, publish, show the peer's video full screen and your own small
});
liveSocket.emit('match:end', {'callId': call.callId}); // hang up
```

When the peer drops (`onParticipantLeft` with reason `disconnected`), wait about 30 seconds before ending: their SDK may be reconnecting.
See [`lib/screens/match_screen.dart`](../lib/screens/match_screen.dart).

## Lounge and direct messages

Chat with no room uses `ChatClient`, with a chat token from the backend:

```dart
final channel = await api.loungeToken();               // POST /v1/chat/lounge/token: { token, wsUrl }
final chat = ChatClient(wsUrl: channel.wsUrl, token: channel.token);
chat.onMessage.listen(addBubble);
final joined = await chat.connect();                    // joined.messages: the recent history
await chat.sendMessage(text, metadata: {'name': me.name, 'avatar': me.avatar});
await chat.close();
```

Direct messages are stored by the backend (`POST /v1/conversations/:id/messages`) and relayed live on the conversation's chat channel.
See [`lib/screens/chat_screens.dart`](../lib/screens/chat_screens.dart).

## Background

Start the foreground service once connected and stop it on leaving (step 2 of the integration guide). With
`pauseCameraInBackground: true`, viewers see the camera off while the app is in the background, and it comes back on return.

## Echo

- `StreamClient.configureAndroidAudio()` first in `main()` gives WebRTC's echo canceller, with the loudspeaker tuning from 0.9.17.
- Two phones on loudspeaker in one room always echo, with any SDK. Test echo from two separate rooms.
- **Copy a sound report** (room menu, or a 1v1 call's Safety menu) copies what VoltKit asks for with an echo report: the phone, Android
  version, where the sound plays, the call volume, and `echoSuppression` and `phoneEchoCanceller` from `getDiagnostics()`. See
  [`lib/rtc/sound_report.dart`](../lib/rtc/sound_report.dart).

VoltKit's own guide: [Echo on Android](https://voltkit.in/docs/flutter-sdk#echo-on-android).
