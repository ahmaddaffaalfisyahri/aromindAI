// lib/perfume_detail_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'perfume.dart';
import 'utils.dart';

class PerfumeDetailPage extends StatelessWidget {
  const PerfumeDetailPage({super.key, required this.perfume, this.allPerfumes});

  final Perfume perfume;
  final List<Perfume>? allPerfumes;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL tidak valid')));
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka link')));
    }
  }

  Widget _marketplaceButton(BuildContext context, String label, String url) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: () => _openUrl(context, url),
      icon: const Icon(Icons.shopping_bag_outlined),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 0,
        backgroundColor: cs.primary.withOpacity(0.08),
        foregroundColor: cs.primary,
      ),
    );
  }

  /// fallback search url containing perfume name + "parfume harga"
  String buildSearchUrl(String platform, String perfumeName) {
    final query = Uri.encodeComponent('$perfumeName parfume harga');
    switch (platform.toLowerCase()) {
      case 'shopee':
        return 'https://shopee.co.id/search?keyword=$query';
      case 'tokopedia':
        return 'https://www.tokopedia.com/search?q=$query';
      case 'tiktok':
      case 'tiktok shop':
        return 'https://www.tiktok.com/search?q=$query';
      default:
        return 'https://www.google.com/search?q=$query';
    }
  }

  /// Try to coerce various dynamic values to int (null if impossible)
  int? _coerceToInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    return null;
  }

  /// Normalize detected gender string; return null for unknown/all
  String? _normalizeGender(dynamic g) {
    if (g == null) return null;
    final s = g.toString().trim();
    if (s.isEmpty) return null;
    final low = s.toLowerCase();
    if (low == 'all / unknown' || low == 'unknown' || low == 'all') return null;
    // common forms: 'male','female','unisex' -> capitalized
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Compact English-style shortener (1.2k, 1.3M) — returns string without ~
  String _compactShort(int n) {
    if (n >= 1000000) {
      final v = n / 1000000.0;
      return v >= 10 ? '${v.toStringAsFixed(0)}M' : '${v.toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      final v = n / 1000.0;
      return v >= 10 ? '${v.toStringAsFixed(0)}k' : '${v.toStringAsFixed(1)}k';
    } else {
      return n.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final idFormat = NumberFormat.decimalPattern('id_ID');

    // If you want to inspect backend shape quickly, uncomment:
    // debugPrint('perfume json: ${perfume.toJson()}');

    // defensive dynamic access so code doesn't break if model changes
    final dyn = perfume as dynamic;

    // Detected gender (prefer model getter)
    String? detectedGender;
    try {
      detectedGender = _normalizeGender(perfume.detectedGender);
    } catch (_) {
      try {
        // try dynamic access
        detectedGender = _normalizeGender(dyn['detectedGender']);
      } catch (_) {
        detectedGender = null;
      }
    }

    // sold estimate: try multiple possible fields / shapes
    int? soldEstimate;
    try {
      soldEstimate ??= _coerceToInt(dyn.soldEstimate);
    } catch (_) {}
    try {
      soldEstimate ??= _coerceToInt(dyn.sold);
    } catch (_) {}
    try {
      soldEstimate ??= _coerceToInt(dyn.sold_count);
    } catch (_) {}
    // inspect toJson map if available
    try {
      final maybe = (dyn.toJson?.call());
      if (maybe is Map) {
        soldEstimate ??= _coerceToInt(maybe['sold']);
        soldEstimate ??= _coerceToInt(maybe['soldEstimate']);
        soldEstimate ??= _coerceToInt(maybe['sold_count']);
        soldEstimate ??= _coerceToInt(maybe['total_sold']);
      }
    } catch (_) {}

    // last fallback: scan marketplace values (some backends put sold inside marketplace)
    try {
      final mp = perfume.marketplace;
      if (soldEstimate == null && mp != null) {
        for (final v in mp.values) {
          final n = _coerceToInt(v);
          if (n != null) {
            soldEstimate = n;
            break;
          }
          // if value is a map, try inside it
          if (v is Map) {
            for (final vv in v.values) {
              final n2 = _coerceToInt(vv);
              if (n2 != null) {
                soldEstimate = n2;
                break;
              }
            }
            if (soldEstimate != null) break;
          }
        }
      }
    } catch (_) {}

    // marketplace or fallback
    String shopee;
    try {
      final m = dyn.marketplaceUrl('shopee');
      shopee = (m != null && m.toString().isNotEmpty)
          ? m.toString()
          : buildSearchUrl('shopee', perfume.perfume);
    } catch (_) {
      shopee = buildSearchUrl('shopee', perfume.perfume);
    }

    String tokopedia;
    try {
      final m = dyn.marketplaceUrl('tokopedia');
      tokopedia = (m != null && m.toString().isNotEmpty)
          ? m.toString()
          : buildSearchUrl('tokopedia', perfume.perfume);
    } catch (_) {
      tokopedia = buildSearchUrl('tokopedia', perfume.perfume);
    }

    String tiktok;
    try {
      final m = dyn.marketplaceUrl('tiktok');
      tiktok = (m != null && m.toString().isNotEmpty)
          ? m.toString()
          : buildSearchUrl('tiktok', perfume.perfume);
    } catch (_) {
      tiktok = buildSearchUrl('tiktok', perfume.perfume);
    }

    final single = perfume.buyUrl;

    // similar perfumes
    final similar = (allPerfumes == null)
        ? <Perfume>[]
        : findTopSimilar(perfume, allPerfumes!, top: 3);

    // note tiers (if model provides helper)
    final tiers = <String, String>{};
    try {
      final t = dyn.extractNoteTiers?.call();
      if (t is Map) {
        t.forEach((k, v) {
          try {
            tiers[k.toString()] = v?.toString() ?? '';
          } catch (_) {}
        });
      }
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text(perfume.perfume),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE + BRAND
            Text(
              perfume.perfume,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              perfume.brand,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // PRICE / GENDER BADGE / RATING / SOLD ESTIMATE (right aligned)
            Row(
              children: [
                if (perfume.price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Rp ${idFormat.format(perfume.price!.round())}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                if (detectedGender != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      detectedGender,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                if (soldEstimate != null)
                  Text(
                    'Perkiraan sudah terjual ${_compactShort(soldEstimate)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // VIBES & NOTES
            Text(
              'Vibes & Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(perfume.notes ?? '-', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),

            // NOTE TIERS
            if ((tiers['top'] ?? '').isNotEmpty) ...[
              Text(
                'Top notes: ${tiers['top']}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
            ],
            if ((tiers['middle'] ?? '').isNotEmpty) ...[
              Text(
                'Middle notes: ${tiers['middle']}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
            ],
            if ((tiers['base'] ?? '').isNotEmpty) ...[
              Text(
                'Base notes: ${tiers['base']}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
            ],

            const SizedBox(height: 18),

            // BUY LINKS
            Text(
              'Beli di Marketplace',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (shopee.isNotEmpty)
                  _marketplaceButton(context, 'Shopee', shopee),
                if (tokopedia.isNotEmpty)
                  _marketplaceButton(context, 'Tokopedia', tokopedia),
                if (tiktok.isNotEmpty)
                  _marketplaceButton(context, 'TikTok Shop', tiktok),
                if ((shopee.isEmpty && tokopedia.isEmpty && tiktok.isEmpty) &&
                    (single != null))
                  _marketplaceButton(context, 'Buka Link', single),
                if ((shopee.isEmpty && tokopedia.isEmpty && tiktok.isEmpty) &&
                    (single == null || single.isEmpty))
                  const Text('Tidak ada link marketplace untuk parfum ini.'),
              ],
            ),

            const SizedBox(height: 24),

            // SIMILAR PERFUMES (open detail page on tap)
            if (similar.isNotEmpty) ...[
              Text(
                'Similar perfumes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: similar.map((p) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_florist_rounded),
                    ),
                    title: Text(p.perfume),
                    subtitle: Text(p.brand),
                    trailing: Text(
                      p.price == null
                          ? '-'
                          : 'Rp ${idFormat.format(p.price!.round())}',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PerfumeDetailPage(
                            perfume: p,
                            allPerfumes: allPerfumes,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
