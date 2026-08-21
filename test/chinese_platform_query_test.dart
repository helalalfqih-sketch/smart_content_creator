import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/services/search/product_search_context.dart';
import 'package:smart_content_creator/services/search/platform_query_builder.dart';

void main() {
  group('PlatformQueryBuilder Chinese Platform Tests', () {
    test('Translates verbose English scalp massager description to Chinese for Douyin, Rednote, Kuaishou, JD', () {
      final raw = "Unknown brand rechargeable electric scalp massager brush with silicone teeth, handheld head massage shampoo brush, lavender purple, model unknown";
      final ctx = ProductSearchContext.fromRawString(raw);

      // Chinese platforms should produce accurate Chinese queries
      final douyinQuery = PlatformQueryBuilder.getBestQuery('douyin', ctx);
      final rednoteQuery = PlatformQueryBuilder.getBestQuery('rednote', ctx);
      final kuaishouQuery = PlatformQueryBuilder.getBestQuery('kuaishou', ctx);
      final jdQuery = PlatformQueryBuilder.getBestQuery('jd', ctx);

      expect(douyinQuery, equals('电动头皮按摩器'));
      expect(rednoteQuery, equals('电动头皮按摩器'));
      expect(kuaishouQuery, equals('电动头皮按摩器'));
      expect(jdQuery, equals('电动头皮按摩器'));

      // TikTok must stay in English and remain untouched
      final tiktokQuery = PlatformQueryBuilder.getBestQuery('tiktok', ctx);
      expect(tiktokQuery.contains('scalp massager'), isTrue);
      expect(tiktokQuery.contains('review'), isTrue);
    });

    test('Uses explicit chinese_name when provided from vision AI', () {
      final ctx = ProductSearchContext.fromMap({
        'name': 'Electric Scalp Massager',
        'chinese_name': '电动头皮按摩爪',
        'category': 'Electronics',
      });

      final douyinQuery = PlatformQueryBuilder.getBestQuery('douyin', ctx);
      final rednoteQuery = PlatformQueryBuilder.getBestQuery('rednote', ctx);
      final kuaishouQuery = PlatformQueryBuilder.getBestQuery('kuaishou', ctx);
      final jdQuery = PlatformQueryBuilder.getBestQuery('jd', ctx);

      expect(douyinQuery, equals('电动头皮按摩爪'));
      expect(rednoteQuery, equals('电动头皮按摩爪'));
      expect(kuaishouQuery, equals('电动头皮按摩爪'));
      expect(jdQuery, equals('电动头皮按摩爪'));
    });

    test('Never searches Unknown on JD when brand is Unknown', () {
      final ctx = ProductSearchContext.fromMap({
        'name': 'Hair Dryer Brush',
        'brand': 'Unknown',
        'model': '',
      });

      final jdQuery = PlatformQueryBuilder.getBestQuery('jd', ctx);
      expect(jdQuery.toLowerCase().contains('unknown'), isFalse);
      expect(jdQuery, equals('高速吹风机'));
    });
  });
}
