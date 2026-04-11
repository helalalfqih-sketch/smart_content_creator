import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/serpapi_services.dart';
import '../services/db_service.dart';

class HomeDashboardController extends GetxController {
  final trendingItems = <Map<String, dynamic>>[].obs;
  final newsItems = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  DBService get _db => Get.find<DBService>();
  GoogleTrendsService get _trendsService => Get.find<GoogleTrendsService>();
  GoogleNewsService get _newsService => Get.find<GoogleNewsService>();

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _fetchTrending(),
        _fetchNews(),
      ]);
    } catch (e) {
      debugPrint("⚠️ HomeDashboard Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchTrending() async {
    const cacheKey = 'home_trends_cache';
    final cachedRecord = await _db.getRecord('response_cache', where: 'input_hash = ?', whereArgs: [cacheKey]);
    final cached = cachedRecord?['response_data'];

    if (cached != null) {
      final decoded = json.decode(cached);
      final timestamp = DateTime.parse(decoded['timestamp']);
      if (DateTime.now().difference(timestamp).inHours < 1) {
        trendingItems.assignAll(List<Map<String, dynamic>>.from(decoded['data']));
        return;
      }
    }

    // Fetch fresh
    final fresh = await _trendsService.getTrendingTopics();
    if (fresh.isNotEmpty) {
      trendingItems.assignAll(fresh);
      await _db.insertRecord(
        'response_cache',
        {
          'input_hash': cacheKey,
          'response_data': json.encode({
            'timestamp': DateTime.now().toIso8601String(),
            'data': fresh,
          }),
          'type': 'home_trends',
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> _fetchNews() async {
    const cacheKey = 'home_news_cache';
    final cachedRecord = await _db.getRecord('response_cache', where: 'input_hash = ?', whereArgs: [cacheKey]);
    final cached = cachedRecord?['response_data'];

    if (cached != null) {
      final decoded = json.decode(cached);
      final timestamp = DateTime.parse(decoded['timestamp']);
      if (DateTime.now().difference(timestamp).inHours < 1) {
        newsItems.assignAll(List<Map<String, dynamic>>.from(decoded['data']));
        return;
      }
    }

    // Fetch fresh - Query for AI & Tech
    final fresh = await _newsService.getLatestNews("أحدث تقنيات الذكاء الاصطناعي");
    if (fresh.isNotEmpty) {
      newsItems.assignAll(fresh);
      await _db.insertRecord(
        'response_cache',
        {
          'input_hash': cacheKey,
          'response_data': json.encode({
            'timestamp': DateTime.now().toIso8601String(),
            'data': fresh,
          }),
          'type': 'home_news',
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }
}
