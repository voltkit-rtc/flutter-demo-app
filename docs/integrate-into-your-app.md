# Integrate VoltKit into your Flutter app

From an empty Flutter app to a working live room, one step at a time. Each step says what to do and why. Every example comes from
this app, cut down to the part you need, with a link to the full file.

You need a VoltKit project and a backend that mints tokens. The backend for this app is
[voltkit-rtc-backend-demo](https://github.com/voltkit-rtc/voltkit-rtc-backend-demo); its
[server SDK guide](https://github.com/voltkit-rtc/voltkit-rtc-backend-demo/blob/main/docs/voltkit-server-sdk.md) covers that side, and its
[API reference](https://github.com/voltkit-rtc/voltkit-rtc-backend-demo/blob/main/docs/api-reference.md) lists the endpoints used below.

> [!NOTE]
> Your VoltKit API secret stays on your backend. The app only ever receives short-lived tokens.

## 1. Install

```yaml
# pubspec.yaml
dependencies:
  voltkit_rtc: ^0.9.17
  flutter_webrtc: ^1.6.3      # draws the video; voltkit_rtc runs on it
  permission_handler: ^12.0.1  # camera and microphone prompts
```

| Requirement | Value |
| --- | --- |
| Flutter | 3.47 or newer |
| Android | `minSdk = 24` in `android/app/build.gradle.kts` |
| iOS | Set up, but not tested by VoltKit or this app |

**Also copy the patched flutter_webrtc.** flutter_webrtc 1.6.3 draws video without an alpha channel, and on some Android phones
release builds then show the background through the video. Copy [`third_party/flutter_webrtc`](../third_party/flutter_webrtc) into your
app and add the override below, or follow VoltKit's recipe:
[See-through video on some Android phones](https://voltkit.in/docs/flutter-sdk#see-through-video-on-some-android-phones).

```yaml
dependency_overrides:
  flutter_webrtc:
    path: third_party/flutter_webrtc
```

## 2. Android permissions and the call service

In `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<application ...>
    <service
        android:name=".LiveCallService"
        android:exported="false"
        android:foregroundServiceType="microphone|mediaPlayback" />
</application>
```

**Why the service:** Android cuts an app's network and microphone within seconds of it leaving the screen. A foreground service with a
notification keeps a call alive. Copy [`LiveCallService.kt`](../android/app/src/main/kotlin/in/voltkit/livedemo/flutter/LiveCallService.kt),
the channel in [`MainActivity.kt`](../android/app/src/main/kotlin/in/voltkit/livedemo/flutter/MainActivity.kt) and
[`lib/rtc/call_service.dart`](../lib/rtc/call_service.dart). Start it once connected, stop it on leaving.

## 3. Set up audio first

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StreamClient.configureAndroidAudio().catchError((Object _) => false);
  runApp(const App());
}
```

**Why first:** WebRTC takes its echo settings only when it starts. This selects WebRTC's own echo canceller, and from 0.9.17 tunes it for
the loudspeaker on phones whose own canceller is Android's software one. If your app calls flutter_webrtc's `WebRTC.initialize`
itself, do that *before* this line: a later `initialize` wipes the tuning. See [`lib/main.dart`](../lib/main.dart).

## 4. Get a token from your backend

```dart
class Credentials {
  Credentials({required this.token, required this.wsUrl, required this.role});
  final String token;
  final String wsUrl;
  final String role; // host, cohost, moderator or viewer

  factory Credentials.fromJson(Map<String, dynamic> j) =>
      Credentials(token: j['token'] as String, wsUrl: j['wsUrl'] as String, role: j['role'] as String);
}

Future<Credentials> joinRoom(String roomId, String sessionToken) async {
  final res = await http.post(
    Uri.parse('https://api.example.com/v1/rooms/$roomId/join'),
    headers: {'Authorization': 'Bearer $sessionToken'}, // your app's own sign-in
  );
  if (res.statusCode != 200) throw Exception('Could not join (${res.statusCode})');
  return Credentials.fromJson((jsonDecode(res.body) as Map<String, dynamic>)['credentials'] as Map<String, dynamic>);
}
```

**Why ask right before joining:** a token lasts ten minutes and only the handshake needs it valid. Once connected, VoltKit keeps the
session going. See [`lib/api/client.dart`](../lib/api/client.dart).

## 5. Ask before going on air

Viewers need no permissions. Ask only when someone is about to publish:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> askForMedia({required bool video}) async {
  final kinds = [if (video) Permission.camera, Permission.microphone];
  final statuses = await kinds.request();
  await Permission.notification.request(); // shows the call's notification; the call works without it
  if (statuses.values.any((s) => s.isPermanentlyDenied)) await openAppSettings();
  return statuses.values.every((s) => s.isGranted);
}
```

This app also shows its own explanation once, so people know they are about to be live. See [`lib/rtc/consent.dart`](../lib/rtc/consent.dart).

## 6. Create the client and connect

```dart
final client = StreamClient(
  wsUrl: credentials.wsUrl,
  token: credentials.token,
  audioMode: AudioMode.communication, // anyone may be asked on stage
  pauseCameraInBackground: true,      // viewers see the camera off, not a frozen picture
);

// Listen before connecting: tracks already live arrive during connect().
client.onTrack.listen(onTrack);
client.onTrackEnded.listen(onTrackEnded);
client.onTrackMuted.listen((_) => redraw()); // RemoteTrack.paused is already current
client.onClosed.listen(onClosed);

await client.connect(metadata: {'name': me.name, 'avatar': me.avatar});
```

**Why `metadata`:** everyone else reads it from `participants` and `onParticipantUpdated`, so names and avatars show without another
request. One client is one session: after `close()` or a final `onClosed`, make a new `StreamClient` to join again. See
[`lib/rtc/room_engine.dart`](../lib/rtc/room_engine.dart), which holds all the room logic in one class.

## 7. Publish

```dart
// A video room. With no quality, publish() sends the highest the project allows: choose one.
await client.publish(video: const VideoPublishOptions(quality: VideoQuality.p720));

// An audio room.
await client.publish(constraints: const {'audio': true, 'video': false});
```

**When:** a host publishes after connecting; anyone else after `onRoleChanged` makes them a co-host. A promotion can move the client to
another server, so `publish()` may fail with the `RpcError` code `disconnected`. A publish that throws is over: call it again once
`onConnectionStateChanged` says `connected`. `_checkOnAir` in the engine does that.

## 8. Show video

```dart
class RemoteVideo extends StatefulWidget {
  const RemoteVideo({super.key, required this.client, required this.track});
  final StreamClient client;
  final RemoteTrack track;
  @override
  State<RemoteVideo> createState() => _RemoteVideoState();
}

class _RemoteVideoState extends State<RemoteVideo> {
  final _renderer = RTCVideoRenderer();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _renderer.initialize().then((_) {
      if (!mounted) return;
      _renderer.srcObject = widget.track.stream;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    widget.client.clearVideoView(widget.track.producerId);
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, box) {
      // Tells VoltKit how big the video is drawn, so this view receives the copy that fits.
      widget.client.setVideoView(widget.track.producerId,
          width: box.maxWidth, height: box.maxHeight, pixelRatio: MediaQuery.devicePixelRatioOf(context));
      return RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
    });
  }
}
```

Your own camera is `client.localStream`; draw it the same way with `mirror: true` for the front camera. Show a track only while
`track.paused` is false. See [`lib/rtc/video_views.dart`](../lib/rtc/video_views.dart).

> [!TIP]
> Put glows and shadows *behind* a video card. A `BoxShadow` painted on top of a card fills all of it and hides the video. See
> `_SpeakingGlow` in [`stage_video.dart`](../lib/components/room/stage_video.dart).

## 9. Controls

```dart
await client.setMicEnabled(!client.micEnabled);
await client.setCamEnabled(!client.camEnabled);
final front = await client.switchCamera();      // true when the front camera is now in use
await client.setSpeakerphoneOn(true);           // the loudspeaker; a headset still wins
```

From 0.9.17, after earphones are unplugged the SDK asks for the loudspeaker again on its own when you had asked for it.

## 10. Handle what goes wrong

Branch on the code and write your own words. [`lib/rtc/errors.dart`](../lib/rtc/errors.dart) has the full mapping:

```dart
({String text, bool canRetry}) joinProblem(Object err) {
  final code = err is RpcError ? err.code : '';
  return switch (code) {
    'room-ended' || 'no-room' => (text: 'This room has ended.', canRetry: false),
    'kicked' => (text: 'You were removed from this room.', canRetry: false),
    'no-capacity' => (text: 'This room is full right now. Try again in a moment.', canRetry: true),
    _ => (text: 'Could not connect. Check your connection and try again.', canRetry: !isTerminalError(code)),
  };
}
```

**Reconnecting needs no code.** The client retries and publishes again by itself. Show it while it happens, with
`onConnectionStateChanged` and `SessionState.reconnecting`, and keep the room on screen. `onClosed` tells you how a session ended:
`left`, `kicked`, `roomClosed`, `replaced` or `gaveUp` (about a minute offline: offer a Join again button).

## 11. Refresh tokens when asked

```dart
client.onTokenExpiring.listen((_) async {
  final fresh = await api.refreshRoomToken(roomId); // POST /v1/rooms/:id/token on the demo backend
  await client.updateToken(fresh.token);            // goes to the live session, no reconnect
});
```

## 12. Leave

```dart
await client.close(); // releases the camera, the microphone and the socket
```

## Next

- Seats, roles, moderation, chat, gifts, 1v1 calls and DMs: [Build the features](build-the-features.md)
- VoltKit's own guide: [Flutter SDK](https://voltkit.in/docs/flutter-sdk)
