import 'package:flutter_test/flutter_test.dart';
import 'package:voltkit_live/rtc/seats.dart';

const Set<String> none = {};

void main() {
  test('numbers from one', () {
    expect(allSeats(3), ['seat-1', 'seat-2', 'seat-3']);
  });

  test('counts an away seat as taken: its holder may come back', () {
    const Claims claims = {'seat-1': SeatClaim('a', 'away')};
    expect(firstFreeSeat(2, claims, none), 'seat-2');
    expect(seatOf(claims, 'a'), 'seat-1');
  });

  test('skips locked seats and runs out', () {
    const Claims claims = {'seat-1': SeatClaim('a', 'held')};
    expect(firstFreeSeat(3, claims, {'seat-2'}), 'seat-3');
    expect(firstFreeSeat(1, claims, none), isNull);
  });

  test('gives the seat asked for when it is free, else the next one', () {
    const Claims claims = {'seat-2': SeatClaim('a', 'held')};
    expect(pickSeat('seat-3', 4, claims, none), 'seat-3');
    expect(pickSeat('seat-2', 4, claims, none), 'seat-1');
    expect(pickSeat(null, 4, claims, none), 'seat-1');
  });

  test('ignores a seat that does not exist in this room', () {
    expect(pickSeat('seat-99', 2, const {}, none), 'seat-1');
    expect(pickSeat(const {'evil': true}, 2, const {}, none), 'seat-1');
  });

  test('follows the service through held, away and free', () {
    Claims claims = {};
    claims = applyClaim(claims, key: 'seat-1', identity: 'a', state: 'held');
    expect(claims['seat-1']?.identity, 'a');
    expect(claims['seat-1']?.state, 'held');
    claims = applyClaim(claims, key: 'seat-1', identity: 'a', state: 'away');
    expect(claims['seat-1']?.away, isTrue);
    claims = applyClaim(claims, key: 'seat-1', identity: null, state: 'free');
    expect(claims['seat-1'], isNull);
  });

  test('does not change the map it was given', () {
    final Claims claims = {};
    applyClaim(claims, key: 'seat-1', identity: 'a', state: 'held');
    expect(claims, isEmpty);
  });
}
