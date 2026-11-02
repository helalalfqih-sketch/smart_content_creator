import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:smart_content_creator/gallery/gallery_item.dart';
import 'package:smart_content_creator/gallery/gallery_store.dart';
import 'package:smart_content_creator/gallery/smart_gallery_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android gallery persists copies, thumbnails, analysis, albums and renames across restart',
    (tester) async {
      final temp = await Directory(
        '${(await getTemporaryDirectory()).path}/gallery-test-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final original = File('${temp.path}/original.jpg');
      final picture = img.Image(width: 80, height: 60);
      img.fill(picture, color: img.ColorRgb8(90, 140, 60));
      await original.writeAsBytes(img.encodeJpg(picture));
      final originalBytes = await original.readAsBytes();
      var store = await GalleryStore.open('owner-one', documents: temp);
      final imported = await store.importFile(
        original,
        name: 'صورة.jpg',
        source: 'phone',
        cancelled: () => false,
      );
      final duplicate = await store.importFile(
        original,
        name: 'another.jpg',
        source: 'phone',
        cancelled: () => false,
      );
      expect(duplicate.duplicate, true);
      expect(duplicate.id, imported.id);
      await store.createAlbum('منتجاتي');
      await store.moveToAlbum([imported.id], 'منتجاتي');
      await store.saveAnalysis(
        imported.id,
        const GalleryAnalysis(
          description: 'صورة خضراء',
          category: 'منتجات',
          text: 'نص',
          suggestedName: 'منتج_أخضر',
          tags: ['أخضر'],
        ),
      );
      await store.rename({imported.id: 'منتج_أخضر.jpg'});
      var items = await store.list();
      expect(await store.thumbnailFile(items.single).exists(), true);
      expect(items.single.album, 'منتجاتي');
      final copies = await store.exportCopies(items, () => false);
      expect(copies.single.path, endsWith('منتج_أخضر.jpg'));
      expect(await copies.single.readAsBytes(), originalBytes);
      await store.close();
      store = await GalleryStore.open('owner-one', documents: temp);
      items = await store.list();
      expect(items.single.name, 'منتج_أخضر.jpg');
      expect(items.single.analysis!.text, 'نص');
      expect(await store.mediaFile(items.single).exists(), true);
      final other = await GalleryStore.open('owner-two', documents: temp);
      expect(await other.list(), isEmpty);
      await other.close();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: SmartGalleryScreen(
            store: store,
            ownerReader: () => 'owner-one',
            keyReader: () => '',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('معرض الصور الذكي'), findsOneWidget);
      expect(find.text('معرض الهاتف'), findsOneWidget);
      expect(find.text('استيراد من Google Photos'), findsOneWidget);
      expect(find.text('منتج_أخضر.jpg'), findsOneWidget);
      await tester.tap(find.text('منتج_أخضر.jpg'));
      await tester.pumpAndSettle();
      expect(find.text('صورة خضراء'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Real SQL transaction and filesystem deletion, not mocked persistence.
      await store.removeAlbum('منتجاتي');
      expect((await store.list()).single.album, isNull);
      await store.deleteCopies(await store.list());
      expect(await store.list(), isEmpty);
      expect(await original.readAsBytes(), originalBytes);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // Original fixture is inside this test's unique temporary directory only.
      await temp.delete(recursive: true);
    },
  );
}
