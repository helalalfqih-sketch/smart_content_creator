import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import 'gallery_controller.dart';
import 'gallery_item.dart';
import 'gallery_store.dart';

class SmartGalleryScreen extends StatefulWidget {
  final String Function()? ownerReader;
  final String Function()? keyReader;
  final GalleryStore? store;
  const SmartGalleryScreen({
    super.key,
    this.ownerReader,
    this.keyReader,
    this.store,
  });
  @override
  State<SmartGalleryScreen> createState() => _SmartGalleryScreenState();
}

class _SmartGalleryScreenState extends State<SmartGalleryScreen> {
  GalleryController? _controller;
  Worker? _accountWatcher;
  String? _error;
  String _owner() {
    if (widget.ownerReader != null) return widget.ownerReader!();
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) return 'guest';
    return 'account:${auth.user?['firestore_uid'] ?? auth.user?['id'] ?? auth.userEmail ?? 'guest'}';
  }

  String _key() =>
      widget.keyReader?.call() ??
      Get.find<SettingsController>().getApiKey(ProviderType.openrouter);
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final owner = _owner();
      final store = widget.store ?? await GalleryStore.open(owner);
      if (!mounted) {
        await store.close();
        return;
      }
      final controller = GalleryController(
        store: store,
        accountIsCurrent: () => _owner() == owner,
        readKey: _key,
      );
      _controller = controller;
      controller.addListener(_changed);
      if (widget.ownerReader == null) {
        _accountWatcher = ever(
          Get.find<AuthController>().rxUser,
          (_) => controller.lockIfAccountChanged(),
        );
      }
      await controller.run(() async {});
      if (mounted) setState(() {});
      await controller.recoverPhoneSelection();
    } catch (error) {
      if (mounted) setState(() => _error = GalleryController.safeError(error));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  GalleryItem _current(GalleryItem item) =>
      _controller!.items.firstWhere((x) => x.id == item.id);

  @override
  void dispose() {
    _accountWatcher?.dispose();
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _analyze(List<GalleryItem> items) async {
    final photos = items.where((x) => !x.isVideo).toList();
    if (photos.isEmpty || photos.length > 20) {
      _controller!.setStatus('حدد من 1 إلى 20 صورة. تحليل الفيديو غير متاح.');
      return;
    }
    if (await _confirm(
          'تحليل ${photos.length} صورة عبر OpenRouter',
          'ستُرسل نسخة مصغرة من الصور المحددة إلى OpenRouter باستخدام مفتاحك، ويُستهلك رصيد حسابك. '
              'لن تُرسل بقية المكتبة. النتائج والأسماء المقترحة قابلة للخطأ وتحتاج مراجعتك.',
          'إرسال وتحليل',
        ) &&
        mounted) {
      await _controller!.analyze(photos);
    }
  }

  Future<void> _rename(List<GalleryItem> items) async {
    final names = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _RenameDialog(all: _controller!.items, items: items),
    );
    if (names != null && mounted) await _controller!.rename(names);
  }

  Future<void> _delete(List<GalleryItem> items) async {
    if (await _confirm(
          'حذف ${items.length} نسخة من المعرض؟',
          'ستُحذف النسخ المستوردة وتحليلاتها من هذا التطبيق. تبقى الملفات الأصلية في الهاتف وGoogle Photos.',
          'حذف النسخ',
        ) &&
        mounted) {
      await _controller!.deleteSelected(items);
    }
  }

  Future<void> _export(List<GalleryItem> items) async {
    final controller = _controller!;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await controller.run(() async {
      controller.setStatus('تجهيز نسخ بالأسماء المعتمدة…');
      final files = await controller.store.exportCopies(
        items,
        () => controller.cancelled,
      );
      if (controller.cancelled) return;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: files.map((f) => XFile(f.path)).toList(),
          sharePositionOrigin: origin,
        ),
      );
      controller.setStatus(
        result.status == ShareResultStatus.dismissed
            ? 'أُغلق التصدير دون اختيار وجهة.'
            : 'فُتحت مشاركة ${files.length} نسخة بالأسماء المعتمدة. اختر تطبيق الملفات لحفظها.',
      );
    });
  }

  Future<void> _move(List<GalleryItem> items) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر ألبوماً'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('دون ألبوم'),
          ),
          for (final album in _controller!.albums)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, album),
              child: Text(album),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      await _controller!.move(items, chosen.isEmpty ? null : chosen);
    }
  }

  Future<void> _createAlbum() async {
    final text = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ألبوم جديد'),
        content: TextField(
          controller: text,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'اسم الألبوم'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null && mounted) {
      await _controller!.run(() async {
        await _controller!.store.createAlbum(name);
        _controller!.setStatus('أُنشئ الألبوم.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final visible = c?.visible ?? <GalleryItem>[];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('معرض الصور الذكي'),
          actions: [
            if (c != null)
              IconButton(
                tooltip: 'حول المعرض',
                icon: const Icon(Icons.more_vert),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مكتبتك الخاصة'),
                    content: const Text(
                      'تُحفظ النسخ والألبومات والتحليلات على هذا الهاتف لهذا الحساب. '
                      'إزالة التطبيق أو بياناته تزيل المكتبة المحلية؛ صدّر الملفات المهمة أولاً. '
                      'Google Photos يتيح اختيار ملفات محددة فقط. لا تُرفع الصور للتحليل إلا بعد موافقتك.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('حسناً'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : c == null
            ? const Center(child: CircularProgressIndicator())
            : c.locked
            ? const Center(
                child: Text('تغير الحساب. أعد فتح المعرض لعرض مكتبتك.'),
              )
            : LayoutBuilder(
                builder: (context, layout) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: layout.maxHeight * 0.55,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${c.items.length} ملف • محفوظ على هذا الهاتف',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: c.busy ? null : _createAlbum,
                                    child: const Text('ألبوم جديد'),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  FilledButton.icon(
                                    onPressed: c.busy ? null : c.importPhone,
                                    icon: const Icon(
                                      Icons.photo_library_rounded,
                                    ),
                                    label: const Text('معرض الهاتف'),
                                  ),
                                  OutlinedButton(
                                    onPressed: c.busy ? null : c.importGoogle,
                                    child: const Text(
                                      'استيراد من Google Photos',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                onChanged: (text) {
                                  c.query = text;
                                  c.changed();
                                },
                                decoration: const InputDecoration(
                                  hintText:
                                      'ابحث بالاسم أو الوصف أو النص أو الوسوم',
                                  prefixIcon: Icon(Icons.search),
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final option in [
                                      ('all', 'الكل'),
                                      ('photo', 'صور'),
                                      ('video', 'فيديو'),
                                    ])
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: 6,
                                            ),
                                        child: ChoiceChip(
                                          label: Text(option.$2),
                                          selected: c.filter == option.$1,
                                          onSelected: (_) {
                                            c.filter = option.$1;
                                            c.selected.clear();
                                            c.changed();
                                          },
                                        ),
                                      ),
                                    FilterChip(
                                      label: Text(
                                        'متشابهة (${c.similar.length})',
                                      ),
                                      selected: c.onlySimilar,
                                      onSelected: (value) {
                                        c.onlySimilar = value;
                                        c.selected.clear();
                                        c.changed();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: c.sort,
                                      underline: const SizedBox.shrink(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'newest',
                                          child: Text('الأحدث استيراداً'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'oldest',
                                          child: Text('الأقدم استيراداً'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'name',
                                          child: Text('الاسم'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'type',
                                          child: Text('النوع'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          c.sort = value;
                                          c.changed();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        c.album = null;
                                        c.selected.clear();
                                        c.changed();
                                      },
                                      child: Text(
                                        c.album == null
                                            ? '✓ جميع الألبومات'
                                            : 'جميع الألبومات',
                                      ),
                                    ),
                                    for (final album in c.albums)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: 6,
                                            ),
                                        child: ChoiceChip(
                                          label: Text(album),
                                          selected: c.album == album,
                                          onSelected: (_) {
                                            c.album = album;
                                            c.selected.clear();
                                            c.changed();
                                          },
                                        ),
                                      ),
                                    if (c.album != null)
                                      TextButton(
                                        onPressed: c.busy
                                            ? null
                                            : () async {
                                                final album = c.album!;
                                                if (await _confirm(
                                                      'حذف ألبوم $album؟',
                                                      'تبقى الصور في المعرض وتُزال تسمية الألبوم فقط.',
                                                      'حذف الألبوم',
                                                    ) &&
                                                    mounted) {
                                                  await c.run(() async {
                                                    await c.store.removeAlbum(
                                                      album,
                                                    );
                                                    c.album = null;
                                                  });
                                                }
                                              },
                                        child: const Text('حذف الألبوم'),
                                      ),
                                  ],
                                ),
                              ),
                              if (c.onlySimilar)
                                const Text(
                                  'تشابه تقريبي للمراجعة؛ لا تُحذف صور تلقائياً.',
                                  style: TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (c.busy) const LinearProgressIndicator(),
                    if (c.status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.status,
                                maxLines: layout.maxHeight < 300 ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (c.busy)
                              TextButton(
                                onPressed: c.cancel,
                                child: const Text('إيقاف'),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  c.items.isEmpty
                                      ? 'ابدأ باستيراد صورك وفيديوهاتك.\nستظهر هنا مع أسمائها وألبوماتها.'
                                      : 'لا توجد ملفات تطابق البحث.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) => GridView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: visible.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          (constraints.maxWidth / 160)
                                              .floor()
                                              .clamp(2, 6),
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.8,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  final selected = c.selected.contains(item.id);
                                  return Semantics(
                                    label: item.name,
                                    selected: selected,
                                    child: InkWell(
                                      onLongPress: c.busy
                                          ? null
                                          : () => c.toggle(item),
                                      onTap: c.busy
                                          ? null
                                          : () async {
                                              if (c.selected.isNotEmpty) {
                                                c.toggle(item);
                                                return;
                                              }
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      _GalleryDetail(
                                                        item: item,
                                                        controller: c,
                                                        analyze: () => _analyze(
                                                          [_current(item)],
                                                        ),
                                                        rename: () => _rename([
                                                          _current(item),
                                                        ]),
                                                        export: () => _export([
                                                          _current(item),
                                                        ]),
                                                      ),
                                                ),
                                              );
                                              if (mounted) await c.refresh();
                                            },
                                      child: Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          border: Border.all(
                                            color: selected
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.file(
                                                    c.store.thumbnailFile(item),
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 480,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const Icon(
                                                              Icons.image,
                                                            ),
                                                  ),
                                                  if (item.isVideo)
                                                    const Center(
                                                      child: Icon(
                                                        Icons.play_arrow,
                                                        color: Colors.white,
                                                        size: 40,
                                                      ),
                                                    ),
                                                  Align(
                                                    alignment:
                                                        Alignment.topLeft,
                                                    child: IconButton(
                                                      tooltip: selected
                                                          ? 'إلغاء التحديد'
                                                          : 'تحديد',
                                                      onPressed: c.busy
                                                          ? null
                                                          : () =>
                                                                c.toggle(item),
                                                      icon: Icon(
                                                        Icons.check_circle,
                                                        color: selected
                                                            ? Colors.tealAccent
                                                            : Colors.black38,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    item
                                                                .analysis
                                                                ?.category
                                                                .isNotEmpty ==
                                                            true
                                                        ? item
                                                              .analysis!
                                                              .category
                                                        : (item.isVideo
                                                              ? 'فيديو'
                                                              : 'صورة'),
                                                    maxLines: 1,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: c == null || c.locked || c.selected.isEmpty
            ? null
            : SafeArea(
                child: Material(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text('${c.selected.length} محدد'),
                            const Spacer(),
                            TextButton(
                              onPressed: c.busy
                                  ? null
                                  : () {
                                      c.selected.addAll(
                                        visible.map((x) => x.id),
                                      );
                                      c.changed();
                                    },
                              child: const Text('تحديد الظاهر'),
                            ),
                            TextButton(
                              onPressed: c.busy
                                  ? null
                                  : () {
                                      c.selected.clear();
                                      c.changed();
                                    },
                              child: const Text('إلغاء التحديد'),
                            ),
                          ],
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilledButton(
                                onPressed: c.busy
                                    ? null
                                    : () => _analyze(c.selection),
                                child: const Text('تحليل الصور'),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () => _rename(c.selection),
                                child: const Text('إعادة تسمية'),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () => _move(c.selection),
                                child: const Text('إلى ألبوم'),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () => _export(c.selection),
                                child: const Text('تصدير'),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () => _delete(c.selection),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final List<GalleryItem> all, items;
  const _RenameDialog({required this.all, required this.items});
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final fields = {
    for (final item in widget.items)
      item.id: TextEditingController(text: item.name),
  };
  final prefix = TextEditingController();
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = planGalleryRename(
      widget.all,
      widget.items,
      fields.map((id, value) => MapEntry(id, value.text)),
    );
    return AlertDialog(
      title: const Text('مراجعة الأسماء الجديدة'),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            if (widget.items.length > 1)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: prefix,
                      decoration: const InputDecoration(
                        labelText: 'اسم أساسي للمجموعة',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (prefix.text.trim().isNotEmpty) {
                        setState(() {
                          for (var i = 0; i < widget.items.length; i++) {
                            fields[widget.items[i].id]!.text =
                                '${prefix.text.trim()}_${(i + 1).toString().padLeft(2, '0')}';
                          }
                        });
                      }
                    },
                    child: const Text('ترقيم'),
                  ),
                ],
              ),
            TextButton(
              onPressed: widget.items.any((x) => x.analysis != null)
                  ? () => setState(() {
                      for (final item in widget.items) {
                        if (item.analysis != null) {
                          fields[item.id]!.text = item.analysis!.suggestedName;
                        }
                      }
                    })
                  : null,
              child: const Text('استخدام اقتراحات التحليل'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: fields[item.id],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: item.name,
                        helperText: 'سيُحفظ: ${plan[item.id]}',
                        helperMaxLines: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Text(
              'تتغير أسماء النسخ داخل التطبيق فقط.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, plan),
          child: const Text('اعتماد الأسماء'),
        ),
      ],
    );
  }
}

class _GalleryDetail extends StatefulWidget {
  final GalleryItem item;
  final GalleryController controller;
  final Future<void> Function() analyze, rename, export;
  const _GalleryDetail({
    required this.item,
    required this.controller,
    required this.analyze,
    required this.rename,
    required this.export,
  });
  @override
  State<_GalleryDetail> createState() => _GalleryDetailState();
}

class _GalleryDetailState extends State<_GalleryDetail> {
  VideoPlayerController? _video;
  bool _videoFailed = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.item.isVideo) {
      _video = VideoPlayerController.file(
        widget.controller.store.mediaFile(widget.item),
      );
      unawaited(
        _video!
            .initialize()
            .then((_) {
              if (mounted) setState(() {});
            })
            .catchError((Object _) {
              if (mounted) setState(() => _videoFailed = true);
            }),
      );
    }
  }

  void _changed() {
    if (widget.controller.locked) unawaited(_video?.pause());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final item =
        c.items.where((x) => x.id == widget.item.id).firstOrNull ?? widget.item;
    final analysis = item.analysis;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: c.locked
            ? const Center(child: Text('تغير الحساب. أعد فتح المعرض.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.4,
                    child: item.isVideo
                        ? _videoFailed
                              ? const Center(
                                  child: Text(
                                    'تعذر تشغيل هذا الفيديو على الهاتف.',
                                  ),
                                )
                              : _video?.value.isInitialized != true
                              ? const Center(child: CircularProgressIndicator())
                              : Center(
                                  child: AspectRatio(
                                    aspectRatio: _video!.value.aspectRatio,
                                    child: VideoPlayer(_video!),
                                  ),
                                )
                        : InteractiveViewer(
                            child: Image.file(
                              c.store.mediaFile(item),
                              fit: BoxFit.contain,
                              cacheWidth: 1800,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('تعذر عرض الصورة.')),
                            ),
                          ),
                  ),
                  if (item.isVideo && _video?.value.isInitialized == true)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _video!.value.isPlaying
                                ? _video!.pause()
                                : _video!.play();
                          }),
                          child: const Text('تشغيل / إيقاف'),
                        ),
                        Expanded(
                          child: VideoProgressIndicator(
                            _video!,
                            allowScrubbing: true,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.source == 'google_photos' ? 'Google Photos' : 'الهاتف'} • ${(item.bytes / 1048576).toStringAsFixed(1)} MB',
                  ),
                  Text(
                    'الاسم الأصلي: ${item.originalName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (item.capturedAt != null)
                    Text(
                      'تاريخ الصورة: ${DateTime.fromMillisecondsSinceEpoch(item.capturedAt!).toLocal().toString().split('.').first}',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!item.isVideo)
                        FilledButton(
                          onPressed: c.busy ? null : widget.analyze,
                          child: Text(
                            analysis == null
                                ? 'تحليل عبر OpenRouter'
                                : 'إعادة التحليل',
                          ),
                        ),
                      OutlinedButton(
                        onPressed: c.busy ? null : widget.rename,
                        child: const Text('إعادة تسمية'),
                      ),
                      TextButton(
                        onPressed: c.busy ? null : widget.export,
                        child: const Text('تصدير نسخة'),
                      ),
                    ],
                  ),
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.status.isNotEmpty) Text(c.status),
                  if (c.busy)
                    TextButton(onPressed: c.cancel, child: const Text('إيقاف')),
                  if (analysis != null) ...[
                    const Divider(),
                    const Text(
                      'تحليل مقترح — راجعه قبل الاستخدام',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(analysis.description),
                    const SizedBox(height: 12),
                    Text('التصنيف: ${analysis.category}'),
                    Text(
                      'الاسم المقترح: ${galleryFileName(analysis.suggestedName, item.extension)}',
                    ),
                    Wrap(
                      spacing: 6,
                      children: analysis.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                    if (analysis.text.isNotEmpty) ...[
                      const Text('النص المستخرج'),
                      SelectableText(analysis.text),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}
