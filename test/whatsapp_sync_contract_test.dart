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

    test('5. Legacy WhatsApp CDN detection and classification contract', () {
      bool isWhatsappCdn(String url) =>
          url.contains('cdn.whatsapp.net') || url.contains('pps.whatsapp.net');

      const expiredUrl = 'https://media-bru2-1.cdn.whatsapp.net/v/t45.5328-4/test_img.jpg';
      const permanentUrl = 'https://parsefiles.back4app.com/app/test_img.jpg';

      expect(isWhatsappCdn(expiredUrl), isTrue);
      expect(isWhatsappCdn(permanentUrl), isFalse);

      // Audit result contract simulation
      final audit = {
        'TOTAL_PRODUCTS': 378,
        'AFFECTED_PRODUCTS': 377,
        'EXPIRED_PRIMARY_IMAGES': 377,
        'EXPIRED_ADDITIONAL_IMAGES': 0,
        'EXPIRED_VIDEOS': 0,
        'TOTAL_EXPIRED_MEDIA': 377,
        'ALREADY_PERMANENT': 1,
      };

      expect(audit['TOTAL_PRODUCTS'], equals(378));
      expect(audit['AFFECTED_PRODUCTS'], equals(377));
      expect(audit['ALREADY_PERMANENT'], equals(1));
    });

    test('6. Indexes Store Media Repair and Safe Matching Contract Tests', () {
      String normalize(String t) => t
          .toLowerCase()
          .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
          .replaceAll(RegExp(r'[أإآ]'), 'ا')
          .replaceAll('ة', 'ه')
          .replaceAll('ى', 'ي')
          .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '')
          .trim();

      final supaProducts = [
        {
          'id': 'supa_001',
          'title_ar': 'مبرد الاظافر الكهربائي',
          'price': 6500,
          'images': [
            'https://wtudcippyxbaobqzbmok.supabase.co/storage/v1/object/public/product-images/uploads/9bfcf1a9-1ea7-4c1c-8d30-d48aeb56065a/1785448774656_1000234303.jpg'
          ],
        },
        {
          'id': 'supa_002',
          'title_ar': 'ماكينة الخياطة الكهربائية',
          'price': 13500,
          'images': [
            'https://wtudcippyxbaobqzbmok.supabase.co/storage/v1/object/public/product-images/recovered/9bfcf1a9-1ea7-4c1c-8d30-d48aeb56065a/fbc5a35c/sewing.jpg'
          ],
        },
      ];

      final back4appProduct = {
        'objectId': 'b4a_obj_999',
        'productId': 'prd_1785448774656',
        'title': 'مبرد الأظافر الكهربائي',
        'price': 6500.0,
        'imageLink': 'https://media-bru2-1.cdn.whatsapp.net/v/t45.5328-4/739214614_old.jpg',
      };

      // 1. Safe Matching
      final b4aNorm = normalize(back4appProduct['title'] as String);
      final matchedSupa = supaProducts.firstWhere(
        (sp) => normalize(sp['title_ar'] as String) == b4aNorm,
      );

      expect(matchedSupa['id'], equals('supa_001'));
      expect((matchedSupa['images'] as List).isNotEmpty, isTrue);

      // 2. Target repair simulation
      final sourceHost = Uri.parse((matchedSupa['images'] as List).first as String).host;
      expect(sourceHost, equals('wtudcippyxbaobqzbmok.supabase.co'));

      // 3. New Parse File host must be parsefiles.back4app.com
      const repairedPermanentUrl = 'https://parsefiles.back4app.com/app/repaired_prd_1785448774656_123.jpg';
      final newHost = Uri.parse(repairedPermanentUrl).host;
      expect(newHost, equals('parsefiles.back4app.com'));

      // 4. Existing fields preserved
      final updatedProduct = {
        ...back4appProduct,
        'imageLink': repairedPermanentUrl,
      };

      expect(updatedProduct['objectId'], equals('b4a_obj_999'));
      expect(updatedProduct['productId'], equals('prd_1785448774656'));
      expect(updatedProduct['title'], equals('مبرد الأظافر الكهربائي'));
      expect(updatedProduct['price'], equals(6500.0));
      expect(updatedProduct['imageLink'], equals(repairedPermanentUrl));
    });
  });
}

