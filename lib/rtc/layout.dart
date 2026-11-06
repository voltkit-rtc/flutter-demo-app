import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../types.dart';

const _gap = 6.0;

List<Rect> _grid(int count, int cols, double x, double y, double w, double h) {
  final rows = (count / cols).ceil();
  final cellW = (w - _gap * (cols - 1)) / cols;
  final cellH = (h - _gap * (rows - 1)) / rows;
  return [
    for (var i = 0; i < count; i++) Rect.fromLTWH(x + (i % cols) * (cellW + _gap), y + (i ~/ cols) * (cellH + _gap), cellW, cellH),
  ];
}

int _gridColumns(int seats) => seats <= 4 ? 2 : 3;

/// Places the video cards: index 0 is the host, the rest are seats in order.
/// `grid` gives everyone the same card. `stage` gives the host the top and the seats a strip below.
List<Rect> videoLayout(int seats, RoomLayout layout, double width, double height) {
  if (layout == 'grid') return _grid(seats, _gridColumns(seats), 0, 0, width, height);

  final others = seats - 1;
  final cols = others <= 3 ? others : (others == 5 ? 3 : 4);
  final rows = (others / cols).ceil();
  final stripH = math.min(height * 0.42, rows * math.min((width / cols) * 1.05, 150.0));
  final hostH = height - stripH - _gap;
  // A row that is not full is stretched, so nothing is left hanging.
  final strip = <Rect>[];
  final rowH = (stripH - _gap * (rows - 1)) / rows;
  var placed = 0;
  for (var r = 0; r < rows; r++) {
    final inRow = math.min(others - placed, r == rows - 1 ? others - placed : cols);
    final cellW = (width - _gap * (inRow - 1)) / inRow;
    for (var c = 0; c < inRow; c++, placed++) {
      strip.add(Rect.fromLTWH(c * (cellW + _gap), hostH + _gap + r * (rowH + _gap), cellW, rowH));
    }
  }
  return [Rect.fromLTWH(0, 0, width, hostH), ...strip];
}

int audioColumns(int seats) => seats == 8 ? 4 : 5;
