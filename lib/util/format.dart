String _trimZero(String s) => s.replaceFirst(RegExp(r'\.0$'), '');

String compact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${_trimZero((n / 1000).toStringAsFixed(n < 10000 ? 1 : 0))}K';
  return '${_trimZero((n / 1000000).toStringAsFixed(1))}M';
}

String clock(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

String shortTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day}/${d.month}';
}

/// 12,345: for the coin balance.
String grouped(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
