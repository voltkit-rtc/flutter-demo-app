sealed class StageItem {
  const StageItem(this.id, this.url);

  final String id;
  final String url;
}

class GiftItem extends StageItem {
  const GiftItem({
    required String id,
    required String url,
    required this.icon,
    required this.fromName,
    required this.toName,
    required this.giftName,
    required this.count,
    required this.tier,
  }) : super(id, url);

  final String icon;
  final String fromName;
  final String toName;
  final String giftName;
  final int count;
  final String tier;
}

class EntranceItem extends StageItem {
  const EntranceItem({required String id, required String url, required this.name, required this.frame}) : super(id, url);

  final String name;
  final String frame;
}

const _limit = 24;

/// Waiting gifts, in order. In a busy room the line can outgrow anyone's patience: past the limit the cheapest
/// waiting item goes first, so a royal gift is not dropped to make way for a rose.
class GiftQueue {
  final _items = <StageItem>[];

  int get size => _items.length;

  void push(StageItem item) {
    if (_items.any((i) => i.id == item.id)) return;
    _items.add(item);
    while (_items.length > _limit) {
      _items.removeAt(_cheapestIndex());
    }
  }

  StageItem? next() => _items.isEmpty ? null : _items.removeAt(0);

  void clear() => _items.clear();

  int _cheapestIndex() {
    int rank(StageItem i) => switch (i) {
          EntranceItem() => 0,
          GiftItem(tier: 'basic') => 1,
          GiftItem(tier: 'premium') => 2,
          GiftItem() => 3,
        };
    var best = 0;
    for (var i = 1; i < _items.length; i++) {
      if (rank(_items[i]) < rank(_items[best])) best = i;
    }
    return best;
  }
}
