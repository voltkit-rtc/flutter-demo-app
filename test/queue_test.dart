import 'package:flutter_test/flutter_test.dart';
import 'package:voltkit_live/gifts/queue.dart';

GiftItem gift(String id, [String tier = 'basic']) =>
    GiftItem(id: id, url: 'u', icon: 'rose', fromName: 'a', toName: 'b', giftName: 'g', count: 1, tier: tier);
EntranceItem entrance(String id) => EntranceItem(id: id, url: 'u', name: 'n', frame: 'lion');

void main() {
  test('plays in order', () {
    final q = GiftQueue()
      ..push(gift('1'))
      ..push(gift('2'));
    expect(q.next()?.id, '1');
    expect(q.next()?.id, '2');
    expect(q.next(), isNull);
  });

  test('ignores a message it already holds', () {
    final q = GiftQueue()
      ..push(gift('1'))
      ..push(gift('1'));
    expect(q.size, 1);
  });

  test('stays bounded in a busy room', () {
    final q = GiftQueue();
    for (var i = 0; i < 200; i++) {
      q.push(gift('$i'));
    }
    expect(q.size, 24);
  });

  test('drops entrances, then the cheapest gifts, before a royal one', () {
    final q = GiftQueue()
      ..push(gift('royal', 'royal'))
      ..push(entrance('e'));
    for (var i = 0; i < 24; i++) {
      q.push(gift('b$i'));
    }
    final ids = <String>[];
    for (var item = q.next(); item != null; item = q.next()) {
      ids.add(item.id);
    }
    expect(ids, contains('royal'));
    expect(ids, isNot(contains('e')));
  });

  test('clears', () {
    final q = GiftQueue()
      ..push(gift('1'))
      ..clear();
    expect(q.size, 0);
    expect(q.next(), isNull);
  });
}
