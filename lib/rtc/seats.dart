/// Seats are VoltKit slots: named places one person holds at a time, kept by the service.
/// These are pure functions over the claims, with no SDK calls, so they are easy to test and to reuse.
class SeatClaim {
  const SeatClaim(this.identity, this.state);

  final String identity;

  /// `held` or `away`.
  final String state;

  bool get away => state == 'away';
}

typedef Claims = Map<String, SeatClaim>;

String seatKey(int n) => 'seat-$n';
int seatNumber(String key) => int.parse(key.replaceFirst('seat-', ''));
List<String> allSeats(int count) => [for (var i = 1; i <= count; i++) seatKey(i)];

/// The seat someone holds. Away counts: their connection dropped and the service keeps it for them.
String? seatOf(Claims claims, String identity) {
  for (final entry in claims.entries) {
    if (entry.value.identity == identity) return entry.key;
  }
  return null;
}

String? firstFreeSeat(int count, Claims claims, Set<String> locked) {
  for (final key in allSeats(count)) {
    if (!claims.containsKey(key) && !locked.contains(key)) return key;
  }
  return null;
}

/// The seat to give someone: the one they asked for if it is still free, else the next free one.
String? pickSeat(Object? wanted, int count, Claims claims, Set<String> locked) {
  if (wanted is String && allSeats(count).contains(wanted) && !claims.containsKey(wanted) && !locked.contains(wanted)) return wanted;
  return firstFreeSeat(count, claims, locked);
}

Claims applyClaim(Claims claims, {required String key, required String? identity, required String state}) {
  final next = {...claims};
  if ((state == 'held' || state == 'away') && identity != null) {
    next[key] = SeatClaim(identity, state);
  } else {
    next.remove(key);
  }
  return next;
}
