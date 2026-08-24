# الأداء والموارد

- CatalogController eager في startup ثم full refresh: `initial_binding.dart:104`, `catalog_controller.dart:574-600`.
- pagination تسلسلية 100/صفحة: `repository.dart:63-112`; لـ1743 صفًا نحو 18 round trip، ثم نسخ/فرز كامل `controller:607-613`.
- `filteredProducts` يعيد copy/filter/sort `773-843`؛ comparator يستعمل DateTime.now `811-821`.
- AiChat Workers بلا dispose: `ai_chat_screen.dart:93-150`.
- uriLinkStream بلا cancel: `auth_controller.dart:148-160,134-138`.
- ستة TextEditingController بلا dispose: `brand_settings_screen.dart:20-25,97-102`.
- PageController بلا dispose: `image_gallery_widget.dart:263-297`.
- APK موجود 82.35 MiB؛ لم يُبن الآن، لذا `PARTIALLY_VERIFIED`. R8/shrink معطل وCI يستعمل no-tree-shake-icons.
- CachedNetworkImage/memCacheWidth مستخدم في الكتالوج، نقطة إيجابية ساكنة.
- Firestore indexes يضم composite واحدًا؛ الملاءمة `NEEDS_RUNTIME_TEST`.
