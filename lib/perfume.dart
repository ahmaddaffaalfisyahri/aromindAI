// lib/perfume.dart
// Robust Perfume model: tolerant parsing + helpful getters

class Perfume {
  final String perfume; // nama parfum
  final String brand;
  final double? price;
  final double score;
  final String? notes;

  // image
  final String? imageUrl;
  final String? localAsset;

  // legacy single buy url
  final String? buyUrl;

  // marketplace can be Map<String, dynamic>, List, or String
  final Map<String, dynamic>? marketplace;

  // optional sold count (may come as int, double, or string)
  final int? sold;
  final int? soldEstimate;

  Perfume({
    required this.perfume,
    required this.brand,
    this.price,
    required this.score,
    this.notes,
    this.imageUrl,
    this.localAsset,
    this.buyUrl,
    this.marketplace,
    this.sold,
    this.soldEstimate,
  });

  /// Helper to coerce dynamic to int
  static int? _toInt(dynamic v) {
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

  static String? _toString(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  /// Construct from JSON / Map with many fallbacks
  factory Perfume.fromJson(Map<String, dynamic> json) {
    String getString(dynamic v) => v == null ? '' : v.toString();

    double? parsePrice(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(RegExp(r'[^\d.]'), '');
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    // marketplace parsing: accept Map, List, String
    Map<String, dynamic>? mp;
    try {
      if (json['marketplace'] is Map) {
        mp = Map<String, dynamic>.from(json['marketplace'] as Map);
      } else if (json['links'] is Map) {
        mp = Map<String, dynamic>.from(json['links'] as Map);
      } else if (json['marketplace'] is String) {
        // single url provided as string -> put as generic key
        mp = {'shop': json['marketplace'].toString()};
      } else if (json['marketplace'] is List) {
        // try to convert list of {"platform": "shopee", "url": "..."}
        final list = json['marketplace'] as List;
        final tmp = <String, dynamic>{};
        for (final item in list) {
          if (item is Map && item['platform'] != null && item['url'] != null) {
            tmp[item['platform'].toString()] = item['url'];
          }
        }
        if (tmp.isNotEmpty) mp = tmp;
      }
    } catch (_) {
      mp = null;
    }

    // images
    String? imageUrl;
    if (json['image_url'] != null)
      imageUrl = getString(json['image_url']);
    else if (json['image'] != null && json['image'] is String)
      imageUrl = getString(json['image']);
    else if (json['imageUrl'] != null)
      imageUrl = getString(json['imageUrl']);

    String? localAsset;
    if (json['local_asset'] != null)
      localAsset = getString(json['local_asset']);
    else if (json['localAsset'] != null)
      localAsset = getString(json['localAsset']);

    // buy url legacy
    String? buy;
    if (json['buy_url'] != null)
      buy = getString(json['buy_url']);
    else if (json['buyUrl'] != null)
      buy = getString(json['buyUrl']);
    else if (json['url'] != null)
      buy = getString(json['url']);
    else if (json['link'] != null)
      buy = getString(json['link']);

    // sold fields
    final soldVal = _toInt(
      json['sold'] ??
          json['sold_count'] ??
          json['soldEstimate'] ??
          json['sold_estimate'],
    );
    final soldEstVal = _toInt(
      json['soldEstimate'] ??
          json['sold_estimate'] ??
          json['soldEstimateApprox'],
    );

    // score tolerant
    double scoreVal = 0.0;
    try {
      if (json['score'] is num)
        scoreVal = (json['score'] as num).toDouble();
      else
        scoreVal = double.tryParse(getString(json['score'])) ?? 0.0;
    } catch (_) {
      scoreVal = 0.0;
    }

    return Perfume(
      perfume: getString(json['perfume'] ?? json['name'] ?? ''),
      brand: getString(json['brand'] ?? json['maker'] ?? ''),
      price: parsePrice(json['price'] ?? json['harga'] ?? json['price_rp']),
      score: scoreVal,
      notes: json['notes']?.toString(),
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      localAsset: (localAsset != null && localAsset.isNotEmpty)
          ? localAsset
          : null,
      buyUrl: (buy != null && buy.isNotEmpty) ? buy : null,
      marketplace: mp,
      sold: soldVal,
      soldEstimate: soldEstVal,
    );
  }

  /// Whether has network image
  bool get hasNetworkImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  /// Whether has local asset
  bool get hasLocalAsset => localAsset != null && localAsset!.trim().isNotEmpty;

  /// marketplaceUrl: case-insensitive search over keys and values;
  /// if map empty but contains a single url-like value, returns it
  String? marketplaceUrl(String key) {
    if (marketplace == null) return null;
    final lowerKey = key.toLowerCase();

    // direct lookup by key insensitive
    for (final k in marketplace!.keys) {
      if (k.toString().toLowerCase() == lowerKey) {
        return _toString(marketplace![k]);
      }
    }

    // substring match on keys e.g. 'shopee_id' -> 'shopee'
    for (final k in marketplace!.keys) {
      if (k.toString().toLowerCase().contains(lowerKey))
        return _toString(marketplace![k]);
    }

    // sometimes values contain hint (list or map)
    for (final v in marketplace!.values) {
      final s = _toString(v);
      if (s != null && s.toLowerCase().contains(lowerKey)) return s;
    }

    // fallback: any url-like value
    for (final v in marketplace!.values) {
      final s = _toString(v);
      if (s == null) continue;
      if (s.startsWith('http') ||
          s.contains('shopee') ||
          s.contains('tokopedia') ||
          s.contains('tiktok'))
        return s;
    }

    // fallback: if only one entry return its value
    if (marketplace!.isNotEmpty) {
      final first = marketplace!.entries.first.value;
      return _toString(first);
    }

    return null;
  }

  /// naive gender detection from notes (kept here for convenience)
  /// returns 'Male','Female','Unisex' or 'All / Unknown'
  String get detectedGender {
    final n = (notes ?? '').toLowerCase();
    if (n.isEmpty) return 'All / Unknown';

    int maleScore = 0;
    int femaleScore = 0;

    final maleKeys = [
      'musk',
      'amber',
      'woody',
      'cedar',
      'vetiver',
      'tobacco',
      'leather',
      'oakmoss',
      'spice',
      'smok',
    ];
    final femaleKeys = [
      'rose',
      'jasmine',
      'vanilla',
      'ylang',
      'lily',
      'powder',
      'peony',
      'fruit',
      'floral',
      'iris',
      'berry',
      'coconut',
    ];

    for (final k in maleKeys) if (n.contains(k)) maleScore += 2;
    for (final k in femaleKeys) if (n.contains(k)) femaleScore += 2;

    final neutral = [
      'citrus',
      'fresh',
      'aquatic',
      'green',
      'herbal',
      'spicy',
      'ambergris',
    ];
    for (final k in neutral)
      if (n.contains(k)) {
        maleScore += 1;
        femaleScore += 1;
      }

    if (maleScore == 0 && femaleScore == 0) return 'All / Unknown';
    if ((maleScore - femaleScore).abs() <= 2) return 'Unisex';
    return maleScore > femaleScore ? 'Male' : 'Female';
  }

  /// return tokens set from notes (used by similarity util)
  Set<String> notesTokens() {
    if (notes == null || notes!.trim().isEmpty) return {};
    final raw = notes!.toLowerCase();
    final cleaned = raw.replaceAll(RegExp(r'[^a-z0-9, ]'), ' ');
    final parts = cleaned
        .split(RegExp(r'[, ]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 1)
        .toSet();
    return parts;
  }

  /// naive note tier splitting: first 2 -> top, next 2-3 -> middle, rest -> base
  Map<String, String> extractNoteTiers() {
    // Clean up notes first - remove trailing dashes and clean up
    String cleanNotes = (notes ?? '')
        .replaceAll(RegExp(r'\s*-\s*-\s*'), ' ') // remove "- -" patterns
        .replaceAll(RegExp(r'\s*-\s*$'), '') // remove trailing dashes
        .replaceAll(RegExp(r'^\s*-\s*'), '') // remove leading dashes
        .trim();

    final parts = cleanNotes
        .toLowerCase()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != '-')
        .toList();
    final top = parts.take(2).join(', ');
    final middle = parts.length > 2 ? parts.skip(2).take(2).join(', ') : '';
    final base = parts.length > 4
        ? parts.skip(4).join(', ')
        : (parts.length > 3 ? parts.skip(3).join(', ') : '');
    return {'top': top, 'middle': middle, 'base': base};
  }

  Map<String, dynamic> toJson() => {
    'perfume': perfume,
    'brand': brand,
    'price': price,
    'score': score,
    'notes': notes,
    'imageUrl': imageUrl,
    'localAsset': localAsset,
    'buyUrl': buyUrl,
    'marketplace': marketplace,
    'sold': sold,
    'soldEstimate': soldEstimate,
  };
}
