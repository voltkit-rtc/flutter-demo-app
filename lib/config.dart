/// The backend. Same one as the React Native demo: only the frontend differs.
/// Point it elsewhere with `--dart-define=API_URL=https://api.example.com`.
const String _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://demo-api-react-native.voltkit.in');

final String apiUrl = _apiUrl.replaceFirst(RegExp(r'/$'), '');

/// Gift animations may be paths on the backend or full URLs on a CDN.
String assetUrl(String pathOrUrl) => RegExp(r'^https?://').hasMatch(pathOrUrl) ? pathOrUrl : '$apiUrl$pathOrUrl';

class Voltkit {
  const Voltkit._();

  /// The app's name. Its React Native twin is VoltKit Native.
  static const appName = 'VoltKit Flutter';
  static const appSuffix = 'Flutter';
  static const site = 'https://voltkit.in';
  static const docs = 'https://voltkit.in/docs';
  static const flutterPage = 'https://voltkit.in/rtc/flutter';
  static const flutterDocs = 'https://voltkit.in/docs/flutter-sdk';
  static const quickstart = 'https://voltkit.in/docs/quickstart';
  static const tagline = 'Connect the world in one click.';
  static const poweredBy = 'Powered by VoltKit RTC';
  static const madeWith = 'Made with Flutter';
  static const demoLine = 'Flutter demo app from VoltKit';
  static const build = 'Build your own live streaming, audio and video app with VoltKit';
}
