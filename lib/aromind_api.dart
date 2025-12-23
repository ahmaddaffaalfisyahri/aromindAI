// lib/aromind_api.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'perfume.dart';

class AromindApi {
  AromindApi();

  final _client = http.Client();

  // Backend production Railway
  final String baseUrl = 'https://aromindbackend-production.up.railway.app';

  Future<List<Perfume>> getRecommendations({
    int age = 25, // default age jika tidak diberikan
    required String activity,
    required String weather,
    required double budgetMin,
    required double budgetMax,
    required String preference,
  }) async {
    final uri = Uri.parse('$baseUrl/recommend');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'age': age,
        'activity': activity,
        'weather': weather,
        'budget_min': budgetMin,
        'budget_max': budgetMax,
        'preference': preference,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Gagal mendapatkan rekomendasi (status ${resp.statusCode})',
      );
    }
    final data = jsonDecode(resp.body);
    final items = (data is Map && data['recommendations'] is List)
        ? data['recommendations'] as List
        : (data is List ? data : []);
    return items
        .map((e) => Perfume.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Perfume?> recognizePerfumeFromBytes(
    Uint8List bytes, {
    String filename = 'img.jpg',
  }) async {
    final uri = Uri.parse('$baseUrl/recognize');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Gagal melakukan recognizer (status ${resp.statusCode})');
    }
    final data = jsonDecode(resp.body);
    if (data is Map && data['matched'] != null) {
      return Perfume.fromJson(data['matched'] as Map<String, dynamic>);
    }
    return null;
  }

  void dispose() {
    try {
      _client.close();
    } catch (_) {}
  }
}
