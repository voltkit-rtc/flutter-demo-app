import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:voltkit_live/rtc/layout.dart';

const w = 400.0;
const h = 500.0;

void main() {
  for (final (seats, layout) in const [(4, 'grid'), (6, 'grid'), (9, 'grid'), (4, 'stage'), (6, 'stage'), (9, 'stage')]) {
    group('$seats cards in $layout layout', () {
      final rects = videoLayout(seats, layout, w, h);

      test('makes a card for everyone', () => expect(rects, hasLength(seats)));

      test('keeps every card inside the stage', () {
        for (final r in rects) {
          expect(r.left, greaterThanOrEqualTo(-0.01));
          expect(r.top, greaterThanOrEqualTo(-0.01));
          expect(r.right, lessThanOrEqualTo(w + 0.01));
          expect(r.bottom, lessThanOrEqualTo(h + 0.01));
          expect(r.width, greaterThan(40));
          expect(r.height, greaterThan(40));
        }
      });

      test('overlaps nothing', () {
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
        }
      });
    });
  }

  test('gives the host the biggest card on stage', () {
    final rects = videoLayout(6, 'stage', w, h);
    double area(Rect r) => r.width * r.height;
    for (final r in rects.skip(1)) {
      expect(area(rects.first), greaterThan(area(r)));
    }
  });

  test('gives everyone the same card in a grid', () {
    expect(videoLayout(6, 'grid', w, h).map((r) => r.width.toStringAsFixed(2)).toSet(), hasLength(1));
  });

  test('uses four audio columns for eight seats and five otherwise', () {
    expect([8, 10, 15].map(audioColumns), [4, 5, 5]);
  });
}
