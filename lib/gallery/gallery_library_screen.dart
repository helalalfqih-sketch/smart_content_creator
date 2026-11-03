import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import 'gallery_item.dart';
import 'gallery_owner.dart';
import 'gallery_store.dart';

class GalleryChatSelection {
  final String owner;
  final List<File> files;
  GalleryChatSelection(this.owner, List<File> files)
    : files = List.unmodifiable(files);
}

/// Local selection only. No AI requests, cloud picker, export or media deletion.
class GalleryLibraryScreen extends StatefulWidget {
  final String Function()? ownerReader;
  final GalleryStore? store;
  final int maxSelection;
  const GalleryLibraryScreen({
    super.key,
    this.ownerReader,
    this.store,
    this.maxSelection = 20,
  }) : assert(maxSelection > 0);

  @override
  State<GalleryLibraryScreen> createState() => _GalleryLibraryScreenState();
}

class _GalleryLibraryScreenState extends State<GalleryLibraryScreen> {
  GalleryStore? _store;
  Worker? _accountWatcher;
  late final String _owner;
  List<GalleryItem> _photos = [];
  final Set<String> _selected = {};
  String _query = '';
  String? _album, _error;
  bool _loading = true, _attaching = false, _locked = false;

  String _readOwner() => widget.ownerReader?.call() ?? currentGalleryOwner();
  bool get _accountCurrent => !_locked && _readOwner() == _owner;

  @override
  void initState() {
    super.initState();
    _owner = _readOwner();
    if (widget.ownerReader == null) {
      _accountWatcher = ever(Get.find<AuthController>().rxUser, (_) {
        if (!_accountCurrent && mounted) {
          setState(() {
            _locked = true;
            _selected.clear();
            _photos = [];
            _error = 'تغير الحساب. أغلق المكتبة وافتحها من الحساب الحالي.';
          });
        }
      });
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    GalleryStore? opened;
    try {
      opened = widget.store ?? await GalleryStore.open(_owner);
      if (!mounted) {
        await opened.close();
        return;
      }
      _store = opened;
      final photos = (await opened.list()).where((x) => !x.isVideo).toList();
      if (!mounted) return;
      if (!_accountCurrent) {
        throw const GalleryFailure('تغير الحساب. أعد فتح المكتبة.');
      }
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is GalleryFailure
              ? error.message
              : 'تعذر فتح المكتبة. أغلقها وحاول مجددًا.';
        });
      }
    }
  }

  void _toggle(GalleryItem item) {
    if (_attaching || !_accountCurrent) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      if (_selected.remove(item.id)) return;
      if (_selected.length >= widget.maxSelection) {
        _error = 'يمكن إرفاق ${widget.maxSelection} صورة في المرة الواحدة.';
      } else {
        _selected.add(item.id);
      }
    });
  }

  Future<void> _attach() async {
    if (_attaching || _selected.isEmpty || _store == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _attaching = true;
      _error = null;
    });
    try {
      final files = <File>[];
      for (final item in _photos.where((x) => _selected.contains(x.id))) {
        if (!_accountCurrent) {
          throw const GalleryFailure('تغير الحساب. أعد فتح المكتبة.');
        }
        final file = _store!.mediaFile(item);
        if (!await file.exists()) {
          throw const GalleryFailure(
            'إحدى الصور لم تعد موجودة. أعد فتح المكتبة أو استورد الصورة مجددًا.',
          );
        }
        final size = await file.length();
        if (size <= 0 || size > GalleryStore.maxPhotoBytes) {
          throw const GalleryFailure(
            'إحدى الصور غير قابلة للإرفاق. اختر صورة صالحة بحجم أقل من 40 ميغابايت.',
          );
        }
        files.add(file);
      }
      if (!mounted) return;
      if (!_accountCurrent) {
        throw const GalleryFailure('تغير الحساب. أعد فتح المكتبة.');
      }
      if (files.length != _selected.length) {
        throw const GalleryFailure('تغيرت الصور المحددة. أعد فتح المكتبة.');
      }
      Navigator.pop(context, GalleryChatSelection(_owner, files));
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is GalleryFailure
              ? error.message
              : 'تعذر إرفاق الصور. تحقق من وجودها وحاول مجددًا.';
        });
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  @override
  void dispose() {
    _accountWatcher?.dispose();
    unawaited(_store?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final photos = _photos
        .where(
          (x) =>
              (_album == null || x.album == _album) &&
              (query.isEmpty ||
                  [
                    x.name,
                    x.originalName,
                    x.analysis?.description ?? '',
                    ...?x.analysis?.tags,
                  ].any((s) => s.toLowerCase().contains(query))),
        )
        .toList();
    final albums =
        _photos.map((x) => x.album).whereType<String>().toSet().toList()
          ..sort();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المكتبة')),
        body: SafeArea(
          child: Column(
            children: [
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'اختر صورًا من معرض الصور الذكي لإضافتها إلى الرسالة. لن تُرسل حتى تضغط إرسال في الدردشة.',
                  ),
                ),
              if (!_loading && !_locked && _photos.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const ValueKey('library-search'),
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      labelText: 'ابحث في صور المكتبة',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('الكل'),
                        selected: _album == null,
                        onSelected: (_) => setState(() => _album = null),
                      ),
                      for (final album in albums)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: ChoiceChip(
                            label: Text(album),
                            selected: _album == album,
                            onSelected: (_) => setState(() => _album = album),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : photos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _locked
                                ? 'المكتبة مقفلة بعد تغيير الحساب.'
                                : _photos.isEmpty
                                ? 'لا توجد صور في المكتبة بعد. أضف صورك من «معرض الصور الذكي ← معرض الهاتف»، ثم ارجع إلى الدردشة.'
                                : 'لا توجد صور تطابق البحث أو الألبوم.',
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final item = photos[index];
                          final selected = _selected.contains(item.id);
                          return Semantics(
                            selected: selected,
                            button: true,
                            label: item.name,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                key: ValueKey('library-photo-${item.id}'),
                                onTap: _attaching ? null : () => _toggle(item),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            _store!.thumbnailFile(item),
                                            fit: BoxFit.cover,
                                            cacheWidth: 256,
                                            errorBuilder:
                                                (context, error, stack) =>
                                                    const Center(
                                                      child: Icon(Icons.image),
                                                    ),
                                          ),
                                          if (selected)
                                            const PositionedDirectional(
                                              top: 6,
                                              end: 6,
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.tealAccent,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('library-attach'),
                    onPressed:
                        _loading || _locked || _attaching || _selected.isEmpty
                        ? null
                        : _attach,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _attaching
                          ? 'تجهيز الصور…'
                          : 'إرفاق (${_selected.length})',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
