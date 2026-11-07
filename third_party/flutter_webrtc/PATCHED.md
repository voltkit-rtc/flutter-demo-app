# flutter_webrtc 1.6.3, patched

This is [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) 1.6.3 (MIT, see LICENSE), with its example, tests and
docs left out and one change on Android:

| File | Change |
| --- | --- |
| `android/src/main/java/com/cloudwebrtc/webrtc/SurfaceTextureRenderer.java` | `EglBase.CONFIG_PLAIN` → `EglBase.CONFIG_RGBA` |
| `android/src/main/java/com/cloudwebrtc/webrtc/utils/EglUtils.java` | `EglBase.createEgl10(EglBase.CONFIG_PLAIN)` → `EglBase.createEgl10(EglBase.CONFIG_RGBA)` |
| `android/src/main/java/com/cloudwebrtc/webrtc/utils/EglUtils.java` | `EglBase.create()` → `EglBase.create(null, EglBase.CONFIG_RGBA)` |

**Why.** The renderer draws each video frame into a Flutter texture through an EGL surface with no alpha channel. Under
Impeller, the texture's alpha then comes out undefined on some GPUs, and the frame is blended with whatever is behind it:
in a video room the room's background shows through the cards and the video looks as if it were behind it. Debug builds of
this app turn Impeller off, so the problem only shows in release builds. The same fix shipped in GetStream's fork of
flutter_webrtc ("Changed the configuration used when creating EGL rendering context to one that supports alpha channel to
fix an issue with Impeller blending background with video texture on some devices", 1.0.12).

This is the recipe in VoltKit's Flutter guide, [See-through video on some Android phones](https://voltkit.in/docs/flutter-sdk#see-through-video-on-some-android-phones).
The app uses this copy through `dependency_overrides` in `pubspec.yaml`. Remove both when a flutter_webrtc release asks for the alpha
channel itself.
