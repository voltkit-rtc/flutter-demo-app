import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/ui.dart';
import '../icons.dart';
import '../theme.dart';
import '../util/routes.dart';
import 'chat_screens.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'match_landing.dart';
import 'profile_screen.dart';

/// Tells the screens inside a tab when they come back into view, as useFocusEffect does in the React Native demo.
final routeObserver = RouteObserver<ModalRoute<void>>();
final _selected = ValueNotifier<int>(0);
final _returned = ValueNotifier<int>(0);

mixin TabFocus<W extends StatefulWidget> on State<W> {
  int get tabIndex;
  void onFocus();

  void _check() {
    if (mounted && _selected.value == tabIndex) onFocus();
  }

  @override
  void initState() {
    super.initState();
    _selected.addListener(_check);
    _returned.addListener(_check);
  }

  @override
  void dispose() {
    _selected.removeListener(_check);
    _returned.removeListener(_check);
    super.dispose();
  }
}

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() => _returned.value++;

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _selected.value = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _selected,
              builder: (context, index, _) => IndexedStack(
                index: index,
                children: const [HomeScreen(), MatchLanding(), InboxScreen(), ProfileScreen()],
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: _TabBar()),
          ],
        ),
      );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.index, required this.id, required this.icon, required this.on, required this.label});

  final int index;
  final String id;
  final IconData icon;
  final IconData on;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: ValueListenableBuilder<int>(
          valueListenable: _selected,
          builder: (context, selected, _) {
            final active = selected == index;
            return Tap(
              id: id,
              label: label,
              selected: active,
              onTap: () => _selected.value = index,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? on : icon, size: 22, color: active ? C.magenta : C.textDim),
                  const SizedBox(height: 2),
                  T(label, variant: V.tiny, color: active ? C.white : C.textDim),
                ],
              ),
            );
          },
        ),
      );
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: EdgeInsets.only(top: 8, bottom: math.max(bottom, 8)),
          decoration: BoxDecoration(
            color: const Color(0xF7100920),
            border: Border(top: BorderSide(color: C.glassBorder, width: hairline(context))),
          ),
          child: const Row(
            children: [
              _TabItem(index: 0, id: 'tab-Home', icon: Ion.homeOutline, on: Ion.home, label: 'Home'),
              _TabItem(index: 1, id: 'tab-Face', icon: Ion.shuffleOutline, on: Ion.shuffle, label: '1v1'),
              Spacer(),
              _TabItem(index: 2, id: 'tab-Chat', icon: Ion.chatbubblesOutline, on: Ion.chatbubbles, label: 'Chat'),
              _TabItem(index: 3, id: 'tab-Me', icon: Ion.personOutline, on: Ion.person, label: 'Me'),
            ],
          ),
        ),
        Tap(
          id: 'tab-create',
          label: 'Start a room',
          onTap: () => unawaited(Navigator.of(context).push(bottomRoute(const CreateScreen()))),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: diagonal(G.accent),
              boxShadow: const [BoxShadow(color: C.magenta, offset: Offset(0, 4), blurRadius: 18)],
            ),
            child: const Icon(Ion.add, size: 30, color: C.white),
          ),
        ),
      ],
    );
  }
}
