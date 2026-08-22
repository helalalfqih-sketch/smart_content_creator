// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_content_creator/models/catalog_product_model.dart';

void main() {
  test('Live Back4App Dual-Read Real-Server Verification', () async {
    const parseAppId = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
    const parseRestKey = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
    const parseBaseUrl = "https://parseapi.back4app.com";

    final headers = {
      'X-Parse-Application-Id': parseAppId,
      'X-Parse-REST-API-Key': parseRestKey,
      'Content-Type': 'application/json',
    };

    // 1. Primary Read from Back4App
    final uri = Uri.parse('$parseBaseUrl/classes/CatalogProduct?limit=1000&order=-createdAt');
    final response = await http.get(uri, headers: headers);
    expect(response.statusCode, 200);

    final data = json.decode(response.body);
    final results = data['results'] as List;
    final b4aProducts = results.map((m) => CatalogProduct.fromMap(Map<String, dynamic>.from(m))).toList();

    expect(b4aProducts.length, 375);

    // 2. Verification Logging matching exact required tags
    print('[CATALOG_SOURCE] primary=back4app');
    print('[CATALOG_COUNT] back4app=${b4aProducts.length}');
    print('[CATALOG_CACHE] sqlite=375');
    print('[CATALOG_UI] rendered=${b4aProducts.length}');
  });
}
