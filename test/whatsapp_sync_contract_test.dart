import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/models/whatsapp_sync_models.dart';

void main() {
  group('📱 WhatsApp Media Sync Contract & Parsing Tests', () {
    test('1. WhatsAppSyncConfig parses existing default values correctly', () {
      final config = WhatsAppSyncConfig.fromMap({});

      expect(config.phoneNumber, equals('+967738609222'));
      expect(config.wabaId, equals('28459237033683884'));
      expect(config.phoneNumberId, equals('1307082469145976'));
      expect(config.metaAppId, equals('1403080371744739'));
      expect(config.verifyToken, equals('indexes_wa_secret_verify_2026'));
      expect(config.autoAiProcess, isTrue);
      expect(config.status, equals('active'));
      expect(config.accounts.length, equals(2));
      expect(config.accounts[0].name, equals('اندكس للتجارة'));
      expect(config.accounts[0].status, equals('مسجّل'));
      expect(config.accounts[1].name, equals('اندكس للتجارة 1'));
      expect(config.accounts[1].status, equals('لم يتم التحقق'));
    });

    test('2. WhatsAppSyncConfig custom serialization and copyWith', () {
      final config = WhatsAppSyncConfig.fromMap({
        'phoneNumber': '+967785574271',
        'mediaCount': 25,
      });

      expect(config.phoneNumber, equals('+967785574271'));
      expect(config.mediaCount, equals(25));

      final updated = config.copyWith(mediaCount: 26, status: 'disconnected');
      expect(updated.mediaCount, equals(26));
      expect(updated.status, equals('disconnected'));
      expect(updated.phoneNumber, equals('+967785574271'));
    });

    test('3. WhatsAppDraftModel parsing with AI suggestions', () {
      final draftMap = {
        'id': 'draft_123',
        'supplierPhone': '+967738609222',
        'title': 'ساعة ابل واش الترا سوداء',
        'description': 'وصف تفصيلي للساعة المستوردة',
        'price': 45000,
        'currency': 'YER',
        'imageLink': 'https://parsefiles.back4app.com/app/image1.jpg',
        'additionalImageLinks': [
          'https://parsefiles.back4app.com/app/image2.jpg',
          'https://parsefiles.back4app.com/app/image3.jpg',
        ],
        'categoryName': 'إلكترونيات',
        'status': 'pending_review',
        'aiSuggestion': {
          'title': 'ساعة ابل واش الترا',
          'description': 'اقتراح ذكاء اصطناعي',
          'category': 'إلكترونيات',
          'price': 45000,
          'tags': ['ساعة', 'ذكية', 'ابل'],
        },
      };

      final draft = WhatsAppDraftModel.fromMap(draftMap);

      expect(draft.id, equals('draft_123'));
      expect(draft.supplierPhone, equals('+967738609222'));
      expect(draft.price, equals(45000.0));
      expect(draft.additionalImageLinks.length, equals(2));
      expect(draft.aiSuggestion, isNotNull);
      expect(draft.aiSuggestion!.tags, contains('ساعة'));
    });

    test('4. WhatsAppAiSuggestion deterministic serialization', () {
      final sug = WhatsAppAiSuggestion(
        title: 'طقم مفكات ومعدات',
        description: 'طقم أدوات صيانة احترافي',
        category: 'معدات وأدوات',
        price: 18000,
        tags: ['طقم', 'مفكات', 'صيانة'],
      );

      final map = sug.toMap();
      expect(map['title'], equals('طقم مفكات ومعدات'));
      expect(map['category'], equals('معدات وأدوات'));
      expect(map['price'], equals(18000.0));
      expect((map['tags'] as List).length, equals(3));
    });
  });
}
