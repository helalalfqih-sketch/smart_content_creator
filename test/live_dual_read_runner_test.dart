// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Live integration test for Back4App catalog security and dual-read mode.
///
/// Requires environment variables:
///   PARSE_APPLICATION_ID
///   PARSE_REST_API_KEY
///
/// Run with:
///   PARSE_APPLICATION_ID=xxx PARSE_REST_API_KEY=yyy flutter test test/live_dual_read_runner_test.dart
///
/// If env vars are missing, the test is skipped cleanly.
void main() {
  final parseAppId = Platform.environment['PARSE_APPLICATION_ID'];
  final parseRestKey = Platform.environment['PARSE_REST_API_KEY'];

  final hasCredentials = parseAppId != null &&
      parseAppId.isNotEmpty &&
      parseRestKey != null &&
      parseRestKey.isNotEmpty;

  Map<String, String> headers() => {
        'X-Parse-Application-Id': parseAppId!,
        'X-Parse-REST-API-Key': parseRestKey!,
        'Content-Type': 'application/json',
      };

  group('Live Back4App Security & Dual-Read Verification', skip: hasCredentials ? null : 'PARSE_APPLICATION_ID / PARSE_REST_API_KEY not set', () {
    // ================================================================
    // 1. CLP NEGATIVE TESTS: Direct class access MUST be DENIED
    // ================================================================
    for (final cls in [
      'CatalogProduct',
      'CatalogProductMedia',
      'CatalogCategory',
      'CatalogSyncState',
      'CatalogChangeLog',
    ]) {
      test('DIRECT CLASS ACCESS: $cls -> DENIED', () async {
        final uri = Uri.parse(
            'https://parseapi.back4app.com/classes/$cls?limit=1');
        final response = await http.get(uri, headers: headers());

        print('$cls -> HTTP ${response.statusCode}: ${response.body}');
        final isDenied = response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.body.contains('"code":119') ||
            response.body.toLowerCase().contains('permission denied');
        expect(
          isDenied,
          isTrue,
          reason:
              '$cls direct class access returned HTTP ${response.statusCode} (${response.body}) — CLP is NOT locked down',
        );
      });
    }

    // ================================================================
    // 2. POSITIVE CLOUD CODE TEST: catalogList (anonymous/public)
    // ================================================================
    test('CLOUD CODE: catalogList returns approved global products', () async {
      final uri = Uri.parse(
          'https://parseapi.back4app.com/functions/catalogList');
      final response = await http.post(
        uri,
        headers: headers(),
        body: json.encode({'page': 1, 'limit': 1000}),
      );

      print('catalogList -> HTTP ${response.statusCode}');
      expect(response.statusCode, 200,
          reason: 'catalogList Cloud Code function must be deployed and working');

      final parsed = json.decode(response.body);
      final result = parsed['result'] as Map<String, dynamic>? ?? {};
      final data = result['data'] as List? ?? [];
      final total = result['total'] ?? data.length;

      print('[CATALOG_SOURCE] primary=back4app');
      print('[CATALOG_COUNT] back4app=$total');

      expect(total, 375,
          reason: 'Expected 375 approved global products from catalogList');

      // Verify scoping: all returned items must be scope=global, status=approved, no deletedAt
      for (final item in data) {
        final scope = item['scope']?.toString() ?? '';
        final status = item['status']?.toString() ?? '';
        final deletedAt = item['deletedAt'];

        if (scope.isNotEmpty) {
          expect(scope, 'global',
              reason:
                  'Anonymous catalogList must not return private products');
        }
        if (status.isNotEmpty) {
          expect(status, 'approved',
              reason:
                  'Anonymous catalogList must not return unapproved products');
        }
        expect(deletedAt, isNull,
            reason:
                'Anonymous catalogList must not return soft-deleted products');
      }

      print('All $total products are scope=global, status=approved, deletedAt=null ✅');
    });
  });
}
