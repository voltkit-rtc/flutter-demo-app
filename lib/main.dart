import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_assets.dart';
import 'components/ui.dart';
import 'config.dart';
import 'icons.dart';
import 'rtc/consent.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tabs.dart';
import 'state/session.dart';
import 'theme.dart';
import 'util/toast.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  ensureE2eSemantics();
  ErrorWidget.builder = (details) => const _Broken();
  runApp(const VoltKitLive());
}

class VoltKitLive extends StatefulWidget {
  const VoltKitLive({super.key});

  @override
  State<VoltKitLive> createState() => _VoltKitLiveState();
}

class _VoltKitLiveState extends State<VoltKitLive> {
  final _session = Session();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SessionScope(
        session: _session,
        child: MaterialApp(
          title: 'VoltKit Live',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          navigatorKey: navigatorKey,
          navigatorObservers: [routeObserver],
          builder: (context, child) => Stack(
            children: [
              if (child != null) Positioned.fill(child: child),
              const ToastHost(),
            ],
          ),
          home: const _Root(),
        ),
      );
}

const _launchTime = Duration(milliseconds: 1600);

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  var _launched = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_launchTime, () => setState(() => _launched = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.status == SessionStatus.loading || !_launched) return const _LaunchScreen();
    return switch (session.status) {
      SessionStatus.offline => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: gapped(14, [
                  const Wordmark(size: 32),
                  const Icon(Ion.cloudOfflineOutline, size: 40, color: C.textDim),
                  const T('Could not reach the server.', color: C.textDim, align: TextAlign.center),
                  GradientButton(label: 'Try again', onTap: () => unawaited(session.load())),
                ]),
              ),
            ),
          ),
        ),
      SessionStatus.guestNeeded => const OnboardingScreen(),
      _ => const Tabs(),
    };
  }
}

/// Every start says what this is, long enough to read, before the app itself.
class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen();

  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen> with SingleTickerProviderStateMixin {
  late final _shown = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Semantics(
          identifier: 'launch-screen',
          child: Backdrop(
            colors: G.launch,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: FadeTransition(
                    opacity: _shown,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(_shown),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Asset(Art.mark, width: 104, height: 104, fit: BoxFit.contain),
                            SizedBox(height: 18),
                            Wordmark(size: 38),
                            SizedBox(height: 8),
                            T(Voltkit.demoLine, variant: V.heading, color: C.textDim),
                            SizedBox(height: 8),
                            T(Voltkit.tagline, variant: V.small, color: C.gold),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 56,
                  child: FadeTransition(opacity: _shown, child: const BuiltWith()),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: C.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const T('Something went wrong', variant: V.title),
                const SizedBox(height: 14),
                GradientButton(label: 'Reload', onTap: () => unawaited(SystemNavigator.pop())),
              ],
            ),
          ),
        ),
      );
}
