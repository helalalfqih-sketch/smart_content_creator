import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:smart_content_creator/gallery/gallery_item.dart';
import 'package:smart_content_creator/gallery/gallery_store.dart';
import 'package:smart_content_creator/gallery/smart_gallery_screen.dart';
import 'package:smart_content_creator/gallery/gallery_library_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
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
      expect(find.textContaining('Google Photos'), findsNothing);
      expect(find.text('منتج_أخضر.jpg'), findsOneWidget);
      await tester.tap(find.text('منتج_أخضر.jpg'));
      await tester.pumpAndSettle();
      expect(find.text('صورة خضراء'), findsOneWidget);
      expect(find.textContaining('نسخة محفوظة على الهاتف'), findsOneWidget);
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

  testWidgets(
    'chat library searches local photos, preserves selections, handles cancellation and missing files, and rejects account changes',
    (tester) async {
      final temp = await Directory(
        '${(await getTemporaryDirectory()).path}/chat-library-test-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      var store = await GalleryStore.open('owner-one', documents: temp);
      Future<GalleryImportResult> addPhoto(String name, img.Color color) async {
        final picture = img.Image(width: 80, height: 60);
        img.fill(picture, color: color);
        final original = File('${temp.path}/$name');
        await original.writeAsBytes(img.encodeJpg(picture));
        return store.importFile(
          original,
          name: name,
          source: 'phone',
          cancelled: () => false,
        );
      }

      final red = await addPhoto('red.jpg', img.ColorRgb8(240, 30, 30));
      final blue = await addPhoto('blue.jpg', img.ColorRgb8(30, 30, 240));
      await store.createAlbum('منتجاتي');
      await store.moveToAlbum([red.id], 'منتجاتي');
      // A video metadata fixture must never become an image attachment.
      await store.db.insert('media', {
        'id': 'video-fixture',
        'name': 'video.mp4',
        'original_name': 'video.mp4',
        'extension': 'mp4',
        'mime_type': 'video/mp4',
        'source': 'phone',
        'digest': 'video-fixture',
        'imported_at': 1,
        'bytes': 1,
      });
      final rows = await store.list();
      final redFile = store.mediaFile(rows.firstWhere((x) => x.id == red.id));
      final redBytes = await redFile.readAsBytes();
      await store.close();
      var owner = 'owner-one';
      final selections = <GalleryChatSelection>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final opened = await GalleryStore.open(
                      owner,
                      documents: temp,
                    );
                    if (!context.mounted) {
                      await opened.close();
                      return;
                    }
                    final result = await Navigator.of(context)
                        .push<GalleryChatSelection>(
                          MaterialPageRoute(
                            builder: (_) => GalleryLibraryScreen(
                              store: opened,
                              ownerReader: () => owner,
                            ),
                          ),
                        );
                    if (result != null) selections.add(result);
                  },
                  child: const Text('افتح المكتبة'),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> waitFor(Finder target) async {
        // The test host opens SQLite before pushing the route. With no spinner
        // yet visible, pumpAndSettle alone can return before native I/O finishes.
        for (
          var attempt = 0;
          attempt < 100 && target.evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
      }

      Future<void> openLibrary() async {
        await tester.tap(find.text('افتح المكتبة'));
        await waitFor(find.text('المكتبة'));
      }

      Future<void> selectPhoto(String id, int selectedCount) async {
        final tile = find.byKey(ValueKey('library-photo-$id'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile.hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('إرفاق ($selectedCount)'), findsOneWidget);
      }

      await openLibrary();
      expect(find.text('video.mp4'), findsNothing);
      expect(find.text('red.jpg'), findsOneWidget);
      expect(find.text('blue.jpg'), findsOneWidget);
      await tester.tap(find.text('منتجاتي'));
      await tester.pumpAndSettle();
      expect(find.text('blue.jpg'), findsNothing);
      await selectPhoto(red.id, 1);
      await tester.tap(find.text('الكل'));
      await tester.enterText(
        find.byKey(const ValueKey('library-search')),
        'blue',
      );
      await tester.pumpAndSettle();
      expect(find.text('red.jpg'), findsNothing);
      await selectPhoto(blue.id, 2);
      expect(selections, isEmpty);
      await tester.tap(find.byKey(const ValueKey('library-attach')));
      await waitFor(find.text('افتح المكتبة'));
      expect(selections.single.owner, 'owner-one');
      expect(selections.single.files.length, 2);
      expect(
        selections.single.files.map((f) => f.path),
        contains(redFile.path),
      );
      expect(await redFile.readAsBytes(), redBytes);

      await openLibrary();
      await selectPhoto(red.id, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(selections.length, 1, reason: 'Back cancels without attaching');

      await openLibrary();
      await selectPhoto(red.id, 1);
      await redFile.delete();
      await tester.tap(find.byKey(const ValueKey('library-attach')));
      await waitFor(find.textContaining('لم تعد موجودة'));
      expect(selections.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await redFile.writeAsBytes(redBytes);

      await openLibrary();
      await selectPhoto(blue.id, 1);
      owner = 'owner-two';
      await tester.tap(find.byKey(const ValueKey('library-attach')));
      await waitFor(find.textContaining('تغير الحساب'));
      expect(selections.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openLibrary();
      expect(find.textContaining('لا توجد صور في المكتبة بعد'), findsOneWidget);
      expect(find.text('red.jpg'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      store = await GalleryStore.open('owner-one', documents: temp);
      expect((await store.list()).length, 3);
      expect(await redFile.readAsBytes(), redBytes);
      await store.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await temp.delete(recursive: true);
    },
  );
}
