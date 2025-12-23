// lib/utils.dart
import 'perfume.dart';

Set<String> _tokenize(String? s) {
  if (s == null || s.isEmpty) return <String>{};
  final cleaned = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9, ]'), ' ');
  final parts = cleaned
      .split(RegExp(r'[, ]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  return parts;
}

/// similarity Jaccard-like
double similarityScore(Perfume a, Perfume b) {
  final sa = _tokenize(a.notes);
  final sb = _tokenize(b.notes);
  if (sa.isEmpty || sb.isEmpty) return 0.0;
  final inter = sa.intersection(sb).length;
  final uni = sa.union(sb).length;
  if (uni == 0) return 0.0;
  return inter / uni;
}

List<Perfume> findTopSimilar(Perfume target, List<Perfume> all, {int top = 3}) {
  final map = <Perfume, double>{};
  for (final p in all) {
    if (p.perfume == target.perfume && p.brand == target.brand) continue;
    final s = similarityScore(target, p);
    if (s > 0) map[p] = s;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => e.key).toList();
}
