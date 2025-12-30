// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'aromind_api.dart';
import 'perfume.dart';
import 'perfume_detail_page.dart';

void main() {
  Intl.defaultLocale = 'id_ID';
  runApp(const AromindApp());
}

/// Formatter ribuan (Rp)
class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final n = int.tryParse(digits) ?? 0;
    final formatted = _fmt.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AromindApp extends StatefulWidget {
  const AromindApp({super.key});

  @override
  State<AromindApp> createState() => _AromindAppState();
}

class _AromindAppState extends State<AromindApp> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    const colorSeed = Color(0xFF00856B);

    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colorSeed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1FFF8),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2F7A64)),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colorSeed,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2F7A64)),
    );

    return MaterialApp(
      title: 'Aromind AI',
      debugShowCheckedModeBanner: false,
      theme: dark ? darkTheme : light,
      home: AromindHomePage(
        darkMode: dark,
        onToggleDark: (v) => setState(() => dark = v),
      ),
    );
  }
}

class AromindHomePage extends StatefulWidget {
  const AromindHomePage({
    super.key,
    required this.darkMode,
    required this.onToggleDark,
  });

  final bool darkMode;
  final void Function(bool) onToggleDark;

  @override
  State<AromindHomePage> createState() => _AromindHomePageState();
}

class _AromindHomePageState extends State<AromindHomePage> {
  final _formKey = GlobalKey<FormState>();
  final budgetMinController = TextEditingController();
  final budgetMaxController = TextEditingController();

  String? activity;
  String? weather;
  String? preference;

  bool loading = false;
  String? errorMessage;
  List<Perfume> results = [];

  // Sorting option: 'price_asc' (termurah), 'price_desc' (termahal), 'score' (default berdasarkan skor)
  String sortBy = 'price_asc';

  final AromindApi api = AromindApi();
  final ImagePicker _picker = ImagePicker();
  final NumberFormat _idFormat = NumberFormat.decimalPattern('id_ID');
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    budgetMinController.dispose();
    budgetMaxController.dispose();
    _scrollController.dispose();
    try {
      api.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      errorMessage = null;
      results = [];
    });

    try {
      final min =
          double.tryParse(
            budgetMinController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      final max =
          double.tryParse(
            budgetMaxController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;

      final recs = await api.getRecommendations(
        activity: activity ?? 'kerja',
        weather: weather ?? 'panas',
        budgetMin: min,
        budgetMax: max,
        preference: preference ?? 'fresh',
      );

      setState(() {
        results = recs;
        if (results.isEmpty) {
          errorMessage =
              "Belum ada parfum yang cocok 😔\nCoba ubah preferensi atau budget.";
        }
      });
    } catch (e) {
      setState(() => errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      setState(() => loading = false);
      // Scroll ke hasil pertama setelah loading selesai
      if (results.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        // Scroll ke posisi awal hasil (setelah form card)
        _scrollController.animateTo(
          450, // Posisi kira-kira setelah form card
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _pickAndRecognize() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => loading = true);
      final Uint8List bytes = await picked.readAsBytes();
      final result = await api.recognizePerfumeFromBytes(
        bytes,
        filename: picked.name,
      );

      setState(() => loading = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gambar tidak dikenali 😢")),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PerfumeDetailPage(perfume: result)),
      );
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error membaca gambar: $e")));
    }
  }

  String _detectVibe(String notes, {String? userPreference}) {
    final n = notes.toLowerCase();

    // Use scoring system for more accurate detection
    int freshScore = 0;
    int sweetScore = 0;
    int woodyScore = 0;
    int floralScore = 0;

    // Fresh keywords
    final freshKeywords = [
      'citrus',
      'lemon',
      'bergamot',
      'lime',
      'orange',
      'grapefruit',
      'aquatic',
      'marine',
      'fresh',
      'green',
      'mint',
    ];
    for (final k in freshKeywords) {
      if (n.contains(k)) freshScore += 2;
    }

    // Sweet keywords
    final sweetKeywords = [
      'vanilla',
      'sweet',
      'caramel',
      'honey',
      'sugar',
      'gourmand',
      'toffee',
      'candy',
      'chocolate',
    ];
    for (final k in sweetKeywords) {
      if (n.contains(k)) sweetScore += 2;
    }

    // Woody keywords (more variations to catch "woody" properly)
    final woodyKeywords = [
      'woody',
      'wood',
      'cedar',
      'sandalwood',
      'oud',
      'vetiver',
      'patchouli',
      'oakmoss',
      'pine',
      'birch',
      'amber',
    ];
    for (final k in woodyKeywords) {
      if (n.contains(k)) woodyScore += 2;
    }

    // Floral keywords
    final floralKeywords = [
      'rose',
      'jasmine',
      'floral',
      'flower',
      'lily',
      'peony',
      'tuberose',
      'iris',
      'violet',
      'magnolia',
      'orchid',
    ];
    for (final k in floralKeywords) {
      if (n.contains(k)) floralScore += 2;
    }

    // Give significant bonus to user's preference if notes contain related keywords
    // This ensures parfums returned by backend for that preference show the correct label
    if (userPreference != null) {
      final pref = userPreference.toLowerCase();
      const preferenceBonus =
          50; // Very large bonus to ensure user preference wins

      switch (pref) {
        case 'fresh':
          if (freshScore > 0) freshScore += preferenceBonus;
          break;
        case 'sweet':
          if (sweetScore > 0) sweetScore += preferenceBonus;
          break;
        case 'woody':
          if (woodyScore > 0) woodyScore += preferenceBonus;
          break;
        case 'floral':
          if (floralScore > 0) floralScore += preferenceBonus;
          break;
        case 'oriental':
          // Oriental often overlaps with woody/sweet/spicy
          if (woodyScore > 0) woodyScore += preferenceBonus;
          if (sweetScore > 0) sweetScore += preferenceBonus ~/ 2;
          break;
      }
    }

    // Find the highest score
    final scores = {
      'Woody': woodyScore,
      'Fresh': freshScore,
      'Sweet': sweetScore,
      'Floral': floralScore,
    };

    // Sort by score descending
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return highest score if > 0, otherwise All-rounder
    if (sorted.first.value > 0) {
      return sorted.first.key;
    }
    return "All-rounder";
  }

  Color _vibeColor(String vibe) {
    switch (vibe) {
      case "Fresh":
        return const Color(0xFF00BFA6);
      case "Sweet":
        return Colors.pinkAccent;
      case "Woody":
        return Colors.brown;
      case "Floral":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeader(ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          child: Icon(Icons.spa, color: cs.primary),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aromind AI",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            Text(
              "Cari parfum sesuai vibe kamu",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormCard(ColorScheme cs) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: activity,
                decoration: InputDecoration(
                  labelText: activity == null ? null : "Aktivitas",
                  hintText: "Aktivitas",
                  prefixIcon: const Icon(Icons.event),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                items: const [
                  DropdownMenuItem(
                    value: "kerja",
                    child: Text("Kerja / Kantor"),
                  ),
                  DropdownMenuItem(value: "kuliah", child: Text("Kuliah")),
                  DropdownMenuItem(value: "date", child: Text("Date")),
                  DropdownMenuItem(value: "hangout", child: Text("Hangout")),
                ],
                onChanged: (v) => setState(() => activity = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: weather,
                decoration: InputDecoration(
                  labelText: weather == null ? null : "Cuaca",
                  hintText: "Cuaca",
                  prefixIcon: const Icon(Icons.wb_sunny),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                items: const [
                  DropdownMenuItem(value: "panas", child: Text("Panas")),
                  DropdownMenuItem(value: "hujan", child: Text("Hujan")),
                  DropdownMenuItem(value: "mendung", child: Text("Mendung")),
                  DropdownMenuItem(value: "malam", child: Text("Malam")),
                ],
                onChanged: (v) => setState(() => weather = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: preference,
                decoration: InputDecoration(
                  labelText: preference == null ? null : "Preferensi Aroma",
                  hintText: "Preferensi Aroma",
                  prefixIcon: const Icon(Icons.favorite),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                items: const [
                  DropdownMenuItem(value: "fresh", child: Text("Fresh")),
                  DropdownMenuItem(value: "woody", child: Text("Woody")),
                  DropdownMenuItem(value: "sweet", child: Text("Sweet")),
                  DropdownMenuItem(value: "oriental", child: Text("Oriental")),
                ],
                onChanged: (v) => setState(() => preference = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: budgetMinController,
                      decoration: InputDecoration(
                        labelText: "Budget Min (Rp)",
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Rp',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: budgetMaxController,
                      decoration: InputDecoration(
                        labelText: "Budget Max (Rp)",
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Rp',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsFormatter(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.primary, width: 2),
                    ),
                  ),
                  child: Text(
                    loading ? 'Mencari...' : 'Cari parfum terbaik',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _pickAndRecognize,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan dari foto parfum'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Perfume> get sortedResults {
    final list = List<Perfume>.from(results);
    switch (sortBy) {
      case 'price_asc':
        // Termurah dulu (harga null di akhir)
        list.sort((a, b) {
          if (a.price == null && b.price == null) return 0;
          if (a.price == null) return 1;
          if (b.price == null) return -1;
          return a.price!.compareTo(b.price!);
        });
        break;
      case 'price_desc':
        // Termahal dulu (harga null di akhir)
        list.sort((a, b) {
          if (a.price == null && b.price == null) return 0;
          if (a.price == null) return 1;
          if (b.price == null) return -1;
          return b.price!.compareTo(a.price!);
        });
        break;
      case 'score':
      default:
        // Berdasarkan skor tertinggi
        list.sort((a, b) => b.score.compareTo(a.score));
    }
    return list;
  }

  Widget _buildSortDropdown(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.sort, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Urutkan:',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sortBy,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: cs.primary),
                  items: const [
                    DropdownMenuItem(
                      value: 'price_asc',
                      child: Text('Termurah', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'price_desc',
                      child: Text('Termahal', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'score',
                      child: Text(
                        'Skor Tertinggi',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => sortBy = v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(ColorScheme cs) {
    return Column(
      children: [
        _buildSortDropdown(cs),
        ...sortedResults.map((p) {
          // Use user's preference as label directly (backend already filtered by preference)
          // Only fallback to scoring if no preference selected
          String vibe;
          if (preference != null && preference!.isNotEmpty) {
            // Capitalize first letter for display
            vibe = preference![0].toUpperCase() + preference!.substring(1);
          } else {
            vibe = _detectVibe(p.notes ?? '', userPreference: preference);
          }
          final vibeColor = _vibeColor(vibe);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vibeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vibe,
                  style: TextStyle(
                    color: vibeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(p.perfume),
              subtitle: Text(p.brand),
              trailing: p.price != null
                  ? Text(
                      "Rp ${_idFormat.format(p.price!.round())}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PerfumeDetailPage(perfume: p),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aromind AI'),
        centerTitle: true,
        actions: [
          Switch(value: widget.darkMode, onChanged: widget.onToggleDark),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(cs),
              const SizedBox(height: 16),
              _buildFormCard(cs),
              const SizedBox(height: 12),
              if (loading) const LinearProgressIndicator(),
              if (!loading && errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (!loading && errorMessage == null && results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      "Belum ada rekomendasi.\nIsi form di atas dulu",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (!loading && results.isNotEmpty) _buildResultList(cs),
            ],
          ),
        ),
      ),
    );
  }
}
