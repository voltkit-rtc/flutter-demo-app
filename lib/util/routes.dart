import 'package:flutter/material.dart';

PageRoute<T> _route<T>(Widget page, Duration time, RouteTransitionsBuilder transition) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: time,
      reverseTransitionDuration: time,
      transitionsBuilder: transition,
    );

Widget _slide(Animation<double> animation, Widget child, Offset from) => SlideTransition(
      position: animation.drive(Tween(begin: from, end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
      child: child,
    );

PageRoute<T> slideRoute<T>(Widget page) => _route(page, const Duration(milliseconds: 280), (_, a, _, child) => _slide(a, child, const Offset(1, 0)));

PageRoute<T> bottomRoute<T>(Widget page) => _route(page, const Duration(milliseconds: 300), (_, a, _, child) => _slide(a, child, const Offset(0, 1)));

PageRoute<T> fadeRoute<T>(Widget page) => _route(page, const Duration(milliseconds: 220), (_, a, _, child) => FadeTransition(opacity: a, child: child));
