import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lng;

  const GeocodingResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class GeocodingService {
  static const _userAgent = 'GloboLogistics/1.0 (soporte@globologistics.mx)';

  Future<List<GeocodingResult>> buscarDireccion(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '5',
      'countrycodes': 'mx',
      'addressdetails': '0',
    });

    final response = await http.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept-Language': 'es-MX,es;q=0.9',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as List<dynamic>;
    final results = <GeocodingResult>[];
    for (final item in data) {
      final m = item as Map<String, dynamic>;
      final lat = double.tryParse(m['lat'] as String? ?? '');
      final lng = double.tryParse(m['lon'] as String? ?? '');
      if (lat == null || lng == null) continue;
      results.add(GeocodingResult(
        displayName: m['display_name'] as String,
        lat: lat,
        lng: lng,
      ));
    }
    return results;
  }
}
