import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../config.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';

const _suggestions = ['Star', 'Nova', 'Echo', 'Blaze', 'Luna', 'Orbit', 'Pixel', 'Comet'];
final _random = math.Random();
String _suggestName() => '${_suggestions[_random.nextInt(_suggestions.length)]}${100 + _random.nextInt(900)}';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController(text: _suggestName());
  var _avatar = avatarKeys[_random.nextInt(avatarKeys.length)];
  var _adult = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ok => _name.text.trim().length >= 2 && _adult;

  Future<void> _enter() async {
    final session = SessionScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.start(_name.text.trim(), _avatar);
    } on ApiError catch (err) {
      if (mounted) {
        setState(() {
          _error = err.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Backdrop(
        colors: G.launch,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, media.padding.top + 14, 20, math.max(media.padding.bottom, media.viewInsets.bottom) + 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: gapped(6, [
                          const Asset(Art.mark, width: 88, height: 88, fit: BoxFit.contain),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [Wordmark(size: 34), SizedBox(width: 6), T(Voltkit.appSuffix, variant: V.title, color: C.textDim)],
                          ),
                          const T(Voltkit.demoLine, variant: V.medium, align: TextAlign.center),
                          const T(Voltkit.tagline, color: C.textDim, align: TextAlign.center),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const T('Pick an avatar', variant: V.small, color: C.textDim),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 74,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: avatarKeys.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final key = avatarKeys[i];
                              return Tap(
                                label: 'Avatar $key',
                                selected: _avatar == key,
                                onTap: () => setState(() => _avatar = key),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _avatar == key ? C.magenta : Colors.transparent, width: 2),
                                  ),
                                  child: Avatar(avatar: key, size: 56),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        const T('Your name', variant: V.small, color: C.textDim),
                        const SizedBox(height: 6),
                        Field(
                          id: 'onboarding-name',
                          controller: _name,
                          maxLength: 24,
                          hint: 'What should people call you?',
                          border: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Tap(
                          id: 'onboarding-age',
                          label: 'I am 18 or older',
                          selected: _adult,
                          onTap: () => setState(() => _adult = !_adult),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _adult ? C.purple : null,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: _adult ? C.purple : C.textDim, width: 1.5),
                                  ),
                                  child: _adult ? const Icon(Ion.checkmark, size: 16, color: C.white) : null,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(child: T('I am 18 or older, and I will be kind. People who break the rules get removed.', variant: V.small, color: C.textDim)),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null) T(_error!, variant: V.small, color: C.danger),
                        const SizedBox(height: 14),
                        GradientButton(id: 'onboarding-enter', label: 'Enter', icon: Ion.arrowForward, disabled: !_ok, loading: _busy, onTap: () => unawaited(_enter())),
                        const SizedBox(height: 6),
                        const T('No account, no password. You are a guest on this phone.', variant: V.tiny, color: C.textFaint, align: TextAlign.center),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const BuiltWith(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
