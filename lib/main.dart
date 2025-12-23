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

  String activity = 'kerja';
  String weather = 'panas';
  String preference = 'fresh';

  bool loading = false;
  String? errorMessage;
  List<Perfume> results = [];

  final AromindApi api = AromindApi();
  final ImagePicker _picker = ImagePicker();
  final NumberFormat _idFormat = NumberFormat.decimalPattern('id_ID');

  @override
  void dispose() {
    budgetMinController.dispose();
    budgetMaxController.dispose();
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
        activity: activity,
        weather: weather,
        budgetMin: min,
        budgetMax: max,
        preference: preference,
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

  String _detectVibe(String notes) {
    final n = notes.toLowerCase();
    if (n.contains("citrus") || n.contains("lemon")) return "Fresh";
    if (n.contains("vanilla") || n.contains("sweet")) return "Sweet";
    if (n.contains("wood") || n.contains("cedar")) return "Woody";
    if (n.contains("rose") || n.contains("jasmine")) return "Floral";
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
                decoration: const InputDecoration(
                  labelText: "Aktivitas",
                  prefixIcon: Icon(Icons.event),
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
                onChanged: (v) => setState(() => activity = v ?? 'kerja'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: weather,
                decoration: const InputDecoration(
                  labelText: "Cuaca",
                  prefixIcon: Icon(Icons.wb_sunny),
                ),
                items: const [
                  DropdownMenuItem(value: "panas", child: Text("Panas")),
                  DropdownMenuItem(value: "hujan", child: Text("Hujan")),
                  DropdownMenuItem(value: "mendung", child: Text("Mendung")),
                  DropdownMenuItem(value: "malam", child: Text("Malam")),
                ],
                onChanged: (v) => setState(() => weather = v ?? 'panas'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: preference,
                decoration: const InputDecoration(
                  labelText: "Preferensi Aroma",
                  prefixIcon: Icon(Icons.favorite),
                ),
                items: const [
                  DropdownMenuItem(value: "fresh", child: Text("Fresh")),
                  DropdownMenuItem(value: "woody", child: Text("Woody")),
                  DropdownMenuItem(value: "sweet", child: Text("Sweet")),
                  DropdownMenuItem(value: "oriental", child: Text("Oriental")),
                ],
                onChanged: (v) => setState(() => preference = v ?? 'fresh'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: budgetMinController,
                      decoration: const InputDecoration(
                        labelText: "Budget Min (Rp)",
                        prefixIcon: Icon(Icons.savings),
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
                      decoration: const InputDecoration(
                        labelText: "Budget Max (Rp)",
                        prefixIcon: Icon(Icons.attach_money),
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
                  child: Text(loading ? 'Mencari...' : 'Cari parfum terbaik'),
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

  Widget _buildResultArea(ColorScheme cs) {
    if (errorMessage != null) {
      return Expanded(
        child: Center(
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (results.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            "Belum ada rekomendasi.\nIsi form di atas dulu",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, i) {
          final p = results[i];
          final vibe = _detectVibe(p.notes ?? '');
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
        },
      ),
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
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: _buildHeader(cs)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildFormCard(cs),
                    const SizedBox(height: 12),
                    if (loading) const LinearProgressIndicator(),
                    if (!loading) _buildResultArea(cs),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
