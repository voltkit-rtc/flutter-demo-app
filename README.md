# VoltKit Flutter

A complete live social app built on [VoltKit RTC](https://voltkit.in/rtc/flutter), written to be read. It has video rooms, audio rooms with
seats, random 1v1 video calls, room chat, direct messages, moderation and SVGA gifts, all on
[`voltkit_rtc`](https://pub.dev/packages/voltkit_rtc).

Use it two ways: run it to see what VoltKit does, or open the file for the feature you need and copy the approach into your own app.

It is the same app as [VoltKit Native](https://github.com/voltkit-rtc/react-native-example-audio-video), the React Native version, on the same
[backend](https://github.com/voltkit-rtc/voltkit-rtc-backend-demo). The two can share a room.

## Run it

You need Flutter 3.47 or newer and the Android SDK. An Android phone is best: an emulator's microphone is silent and its cameras are simulated.

```bash
git clone https://github.com/voltkit-rtc/flutter-demo-app.git
cd flutter-demo-app
flutter pub get
flutter run
```

That runs against the hosted demo backend, so there is nothing else to set up. To use your own, run the
[backend](https://github.com/voltkit-rtc/voltkit-rtc-backend-demo#run-it) and point the app at it:

```bash
flutter run --dart-define=API_URL=https://api.example.com
```

> [!NOTE]
> Your VoltKit secret stays on the backend. The app only ever receives short-lived tokens.

## Where each feature lives

| Feature | Code | VoltKit APIs it shows |
| --- | --- | --- |
| Joining and leaving a room | [`lib/screens/room_screen.dart`](lib/screens/room_screen.dart) | `onClosed`, `ClosedReason` |
| Everything a room does | [`lib/rtc/room_engine.dart`](lib/rtc/room_engine.dart) | `StreamClient`, `connect`, `publish`, `onTrack`, `onTokenExpiring`, `updateToken` |
| Video cards | [`lib/components/room/stage_video.dart`](lib/components/room/stage_video.dart) | `onActiveSpeakers`, `onStreamFallback` |
| Drawing video | [`lib/rtc/video_views.dart`](lib/rtc/video_views.dart) | `RTCVideoRenderer`, `setVideoView`, `clearVideoView` |
| Audio seats | [`lib/components/room/stage_audio.dart`](lib/components/room/stage_audio.dart) | `onActiveSpeakers` |
| Seats | [`lib/rtc/seats.dart`](lib/rtc/seats.dart) | `claim`, `release`, `blockSlot`, `onClaimChanged` |
| Who may do what | [`lib/rtc/permissions.dart`](lib/rtc/permissions.dart) | The four roles |
| Moderation | [`lib/components/room/sheets.dart`](lib/components/room/sheets.dart) | `forceMute`, `kick`, `promote`, `muteChat`, `deleteMessage` |
| Permissions and consent | [`lib/rtc/consent.dart`](lib/rtc/consent.dart) | Asked before going on air, never for viewers |
| Error messages | [`lib/rtc/errors.dart`](lib/rtc/errors.dart) | `RpcError`, `isTerminalError`, `ClosedReason` |
| 1v1 calls | [`lib/screens/match_screen.dart`](lib/screens/match_screen.dart) | A room per call, `onParticipantLeft` |
| Room chat and hearts | [`lib/components/room/chat.dart`](lib/components/room/chat.dart), [`reactions.dart`](lib/components/room/reactions.dart) | `sendMessage`, `getMessages`, ephemeral messages |
| Lounge and direct messages | [`lib/screens/chat_screens.dart`](lib/screens/chat_screens.dart) | `ChatClient` |
| SVGA gifts and entrance effects | [`lib/gifts/`](lib/gifts/) | Gift messages sent by the backend |
| Staying alive in the background | [`lib/rtc/call_service.dart`](lib/rtc/call_service.dart), [`LiveCallService.kt`](android/app/src/main/kotlin/in/voltkit/livedemo/flutter/LiveCallService.kt) | `pauseCameraInBackground` |

## How a room works

Everything VoltKit lives in one class, [`RoomEngine`](lib/rtc/room_engine.dart). Widgets draw its state and call its methods, and hold no SDK logic.

**Wire events before connecting.** Tracks that are already live arrive during `connect()`.

**The host's client grants seats.** Only a host may promote, so a viewer raises a hand and the host's app claims the seat, then promotes:

```dart
await client.raiseHand(metadata: {'requestRole': 'cohost', 'slot': 'seat-3'});   // viewer

await client.claim('seat-3', identity: viewer);                                  // host: if the seat has gone, nothing has happened yet
await client.promote(viewer, Role.cohost);
```

**Publish when `onRoleChanged` names you.** A promotion can move the client to another server, so `publish()` can fail with `disconnected`. Try again once
`connectionState` is `connected`. `_checkOnAir` in the engine does this, and keeps what the person wants apart from whether they are publishing.

**Remember to leave.** `close()` releases the camera, the microphone and the socket. A closed client stays closed, so rejoining makes a new `StreamClient`.

## Good to know

| Thing | Why |
| --- | --- |
| `StreamClient.configureAndroidAudio()` is the first line of `main()` | It selects WebRTC's own echo canceller, and WebRTC takes that setting only when it starts |
| Two phones in one room echo on the loudspeaker | Each canceller removes only its own speaker's sound. Test in different rooms, or with earphones on one phone |
| A foreground service runs while in a room | Android cuts an app's network and microphone within seconds of leaving the screen without one |
| `permission_handler` is pinned to 12.0.1 | Version 13 needs compile SDK 37, newer than the Android Gradle Plugin that Flutter 3.47 ships with |
| Impeller is off in debug builds | Its OpenGL path crashes an emulator with no real GPU. Release builds keep it. Delete the line in `android/app/src/debug/AndroidManifest.xml` to run it on a phone |

## Tests

```bash
flutter analyze
flutter test    # seats, permissions, layouts, the gift queue, and every gift file through the SVGA player
```

The room flows were tested on an Android emulator against the live backend and real VoltKit rooms, with browser-SDK clients as the other people in the room. VoltKit
has not tested `voltkit_rtc` on an iPhone, and neither has this app: the iOS project is set up, but treat it as untested.

## Release builds

Copy [`android/key.properties.example`](android/key.properties.example) to `android/key.properties` and fill in your keystore. Without one the release build
is left unsigned, so a debug key never reaches users.

```bash
flutter build apk --release
```

## Credits

MIT, see [LICENSE](LICENSE). The VoltKit name and logo are not part of that licence. Outfit is under the SIL Open Font License, and Ionicons under MIT.
