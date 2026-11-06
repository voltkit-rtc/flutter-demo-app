import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../components/ui.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';
import '../util/routes.dart';
import 'match_screen.dart';
import 'tabs.dart';

const _rules = ['You are matched with someone at random', 'Tap Next at any time to meet someone new', 'Report or block anyone from the call'];

class MatchLanding extends StatefulWidget {
  const MatchLanding({super.key});

  @override
  State<MatchLanding> createState() => _MatchLandingState();
}

class _MatchLandingState extends State<MatchLanding> with TabFocus {
  @override
  int get tabIndex => 1;

  var _waiting = 0;

  @override
  void onFocus() {
    api.stats().then((s) {
      if (mounted) setState(() => _waiting = s.waiting);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final guest = SessionScope.of(context).guest;
    return Backdrop(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const T('1v1 Face Live', variant: V.display),
            const SizedBox(height: 4),
            const T('Face to face with someone new, in one tap.', color: C.textDim),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: gapped(16, [
                  Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: vertical(G.match)),
                      child: const Icon(Ion.videocam, size: 52, color: C.white),
                    ),
                  ),
                  Panel(
                    child: Column(
                      children: gapped(8, [
                        for (final rule in _rules)
                          Row(
                            children: [
                              const Icon(Ion.checkmarkCircle, size: 17, color: C.success),
                              const SizedBox(width: 8),
                              Expanded(child: T(rule, variant: V.small, color: C.textDim)),
                            ],
                          ),
                      ]),
                    ),
                  ),
                  if (_waiting > 0)
                    T('$_waiting ${_waiting == 1 ? 'person is' : 'people are'} waiting now', variant: V.small, color: C.gold, align: TextAlign.center),
                ]),
              ),
            ),
            GradientButton(
              id: 'match-start',
              label: 'Start matching',
              icon: Ion.shuffle,
              disabled: guest.restricted,
              colors: G.match,
              onTap: () => unawaited(Navigator.of(context).push(fadeRoute(const MatchScreen()))),
            ),
            const SizedBox(height: 12),
            const PoweredBy(),
          ],
        ),
      ),
    );
  }
}
