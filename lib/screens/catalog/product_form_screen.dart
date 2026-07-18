import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart' as sp;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/catalog_product_model.dart';
import '../../controllers/catalog_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/unified_ai_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/product_matching_service.dart';
import '../../theme/app_theme.dart';

/// 📝 شاشة نموذج إضافة وتعديل المنتج مع دمج نظام المطابقة الذكي
class ProductFormScreen extends StatefulWidget {
  final CatalogProduct? editProduct;
  const ProductFormScreen({super.key, this.editProduct});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ctrl = Get.find<CatalogController>();
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _gCategoryCtrl;
  late final TextEditingController _fbCategoryCtrl;
  late final TextEditingController _quantityCtrl;

  String _availability = 'in stock';
  String _condition = 'new';
  String _currency = 'YER';
  bool _isAnalyzing = false;
  bool _isOptimizingDesc = false;
  String _status = 'approved';
  String? _categoryId;

  final List<String> _currencies = ['YER', 'USD', 'SAR', 'AED', 'EGP'];
  final List<String> _availabilityOptions = ['in stock', 'out of stock'];
  final List<String> _conditionOptions = ['new', 'used'];

  @override
  void initState() {
    super.initState();
    final p = widget.editProduct;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _linkCtrl = TextEditingController(text: p?.link ?? '');
    _colorCtrl = TextEditingController(text: p?.color ?? '');
    _sizeCtrl = TextEditingController(text: p?.size ?? '');
    _gCategoryCtrl = TextEditingController(text: p?.googleProductCategory ?? '');
    _fbCategoryCtrl = TextEditingController(text: p?.fbProductCategory ?? '');
    _quantityCtrl = TextEditingController(text: p != null ? p.quantity.toString() : '1');
    _availability = p?.availability ?? 'in stock';
    _condition = p?.condition ?? 'new';
    _currency = p?.currency ?? 'YER';
    _status = p?.status ?? 'approved';
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _brandCtrl, _linkCtrl,
      _colorCtrl, _sizeCtrl, _gCategoryCtrl, _fbCategoryCtrl, _quantityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(
          widget.editProduct == null ? '➕ منتج جديد' : '✏️ تعديل المنتج',
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveProduct,
            icon: const Icon(Icons.check_rounded, color: Colors.green),
            label: const Text(
              'حفظ',
              style: TextStyle(
                color: Colors.green,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── الصور ──
            const _SectionTitle(title: '📷 صور المنتج'),
            const SizedBox(height: 12),
            _buildImagesSection(),
            const SizedBox(height: 20),

            // ── الفيديو ──
            const _SectionTitle(title: '🎥 فيديو المنتج (اختياري)'),
            const SizedBox(height: 12),
            _buildVideoSection(),
            const SizedBox(height: 20),

            // ── AI ──
            _buildAiSection(),
            const SizedBox(height: 20),

            // ── Admin Approval ──
            if (Get.find<AuthController>().isAdmin) ...[
              const _SectionTitle(title: '🛡️ اعتماد المنتج (للمشرفين)'),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'حالة المنتج',
                value: _status,
                items: ['pending', 'approved', 'rejected'],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 20),
            ],

            // ── فئة المنتج ──
            const _SectionTitle(title: '🗂️ فئة المنتج'),
            const SizedBox(height: 12),
            Obx(() {
              final cats = ctrl.allCategories;
              final valueExists = cats.any((c) => c.id == _categoryId);
              final initialVal = valueExists ? _categoryId : 'other';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(initialVal),
                    initialValue: initialVal,
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'الفئة الرئيسية *',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _categoryId = val;
                          final catInfo = cats.firstWhere((e) => e.id == val);
                          _gCategoryCtrl.text = catInfo.googleCategory;
                          _fbCategoryCtrl.text = catInfo.fbCategory;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _showManageCategoriesDialog,
                        icon: const Icon(Icons.settings_suggest_rounded, size: 16, color: Color(0xFFe94560)),
                        label: const Text(
                          'إدارة الفئات وإضافة فئة مخصصة',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            color: Color(0xFFe94560),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),

            // ── العنوان ──
            const _SectionTitle(title: '📌 معلومات المنتج'),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _titleCtrl,
              label: 'عنوان المنتج *',
              hint: 'مثال: قميص قطني أزرق للرجال',
              validator: (v) => v == null || v.isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle(title: '📝 وصف المنتج *'),
                _isOptimizingDesc
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _optimizeDescriptionWithAi,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.primary),
                        label: const Text(
                          'تحسين وتسعير ذكي 🪄',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(
              ctrl: _descCtrl,
              label: 'وصف المنتج *',
              hint: 'ادخل تفاصيل المنتج والسعر هنا ثم اضغط تحسين ذكي...',
              maxLines: 5,
              validator: (v) => v == null || v.isEmpty ? 'الوصف مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _brandCtrl,
              label: 'العلامة التجارية',
              hint: 'مثال: Samsung، Apple...',
            ),
            const SizedBox(height: 20),

            // ── السعر ──
            const _SectionTitle(title: '💰 السعر والتوفر'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildField(
                    ctrl: _priceCtrl,
                    label: 'السعر *',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'السعر مطلوب';
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'العملة',
                    value: _currency,
                    items: _currencies,
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'التوفر',
                    value: _availability,
                    items: _availabilityOptions,
                    onChanged: (v) => setState(() => _availability = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'الحالة',
                    value: _condition,
                    items: _conditionOptions,
                    onChanged: (v) => setState(() => _condition = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _quantityCtrl,
              label: 'الكمية المتاحة',
              hint: '1',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // ── تفاصيل إضافية ──
            const _SectionTitle(title: '📂 تفاصيل إضافية'),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _gCategoryCtrl,
              label: 'فئة جوجل (اختياري)',
              hint: 'مثال: Apparel & Accessories > Clothing',
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _fbCategoryCtrl,
              label: 'فئة فيسبوك (اختياري)',
              hint: 'مثال: Clothing & Accessories > Clothing',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    ctrl: _colorCtrl,
                    label: 'اللون',
                    hint: 'مثال: أزرق ملكي',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    ctrl: _sizeCtrl,
                    label: 'المقاس',
                    hint: 'مثال: L، XL، 42',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _linkCtrl,
              label: 'رابط صفحة المنتج (اختياري)',
              hint: 'https://...',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),

            // ── مشاركة المنتج ──
            if (widget.editProduct != null) ...[
              const _SectionTitle(title: '📤 مشاركة المنتج'),
              const SizedBox(height: 12),
              _buildShareSection(),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── قسم المشاركة ──
  Widget _buildShareSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شارك المنتج عبر:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // ── واتساب ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.chat_rounded,
                  label: 'واتساب',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareToWhatsApp(),
                ),
              ),
              const SizedBox(width: 10),
              // ── فيسبوك ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.facebook_rounded,
                  label: 'فيسبوك',
                  color: const Color(0xFF1877F2),
                  onTap: () {
                    if (widget.editProduct != null) {
                      final tempProduct = CatalogProduct(
                        id: widget.editProduct!.id,
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim(),
                        price: double.tryParse(_priceCtrl.text.trim()) ?? widget.editProduct!.price,
                        currency: _currency,
                        link: _linkCtrl.text.trim(),
                        imageLink: widget.editProduct!.imageLink,
                      );
                      _shareProductFromForm(tempProduct, platform: 'facebook');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              // ── انستقرام ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'انستقرام',
                  color: const Color(0xFFE1306C),
                  onTap: () => _shareToInstagram(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final product = widget.editProduct;
    if (product == null) return;
    try {
      final secure = Get.find<SecureStorageService>();
      final sig = await secure.getStoreSignature();
      final phone = sig['phone'] ?? '';
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
        cleanPhone = '967$cleanPhone';
      }
      final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : product.title;
      final price = _priceCtrl.text.trim().isNotEmpty ? '${ _priceCtrl.text.trim()} $_currency' : product.formattedPrice;
      final desc = _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : product.description;
      final text = Uri.encodeComponent(
        '🛍️ *$title*\n\n$desc\n\n💰 السعر: $price\n\nللطلب والاستفسار تواصل معنا 👇',
      );
      final waUrl = cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=$text'
          : 'https://wa.me/?text=$text';
      await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر فتح واتساب: $e',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373));
    }
  }

  Future<void> _shareToInstagram() async {
    try {
      final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (widget.editProduct?.title ?? '');
      final price = _priceCtrl.text.trim().isNotEmpty ? '${_priceCtrl.text.trim()} $_currency' : (widget.editProduct?.formattedPrice ?? '');
      final desc = _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : (widget.editProduct?.description ?? '');
      await sp.SharePlus.instance.share(
        sp.ShareParams(
          text: '🛍️ $title\n\n$desc\n\n💰 السعر: $price\n\n#متجر #تسوق #عروض',
        ),
      );
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر المشاركة: $e',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373));
    }
  }

  Future<void> _shareProductFromForm(CatalogProduct product, {String platform = 'general'}) async {
    String shareUrl = _linkCtrl.text.trim();
    if (shareUrl.isEmpty) {
      try {
        final secure = Get.find<SecureStorageService>();
        final sig = await secure.getStoreSignature();
        final phone = sig['phone'] ?? '';
        if (phone.isNotEmpty) {
          String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
            cleanPhone = '967$cleanPhone';
          }
          final text = Uri.encodeComponent('السلام عليكم، أريد الاستفسار عن: ${product.title}');
          shareUrl = 'https://wa.me/$cleanPhone?text=$text';
        }
      } catch (_) {}
    }

    if (platform == 'facebook') {
      final imagesList = List<String>.from(ctrl.pickedImages);
      // استخدام مشاركة الصور
      _shareGeneralWithDescAndImages(
        title: product.title,
        description: product.description,
        formattedPrice: product.formattedPrice,
        shareUrl: shareUrl,
        images: imagesList,
      );
    }
  }

  Future<void> _shareGeneralWithDescAndImages({
    required String title,
    required String description,
    required String formattedPrice,
    required String shareUrl,
    required List<String> images,
  }) async {
    final cleanLink = shareUrl.contains('wa.me/') ? 'للتواصل عبر واتساب 💬' : shareUrl;
    final text = '$title\n\n$description\n\nالسعر: $formattedPrice\n\n$cleanLink';

    try {
      await Clipboard.setData(ClipboardData(text: text));
      Get.snackbar(
        '📋 تم نسخ الوصف للحافظة',
        'تم نسخ وصف المنتج تلقائياً! يمكنك لصقه بسهولة عند مشاركته في فيسبوك.',
        backgroundColor: const Color(0xFF1A1A3A),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (_) {}

    final List<sp.XFile> xFiles = [];
    final allImages = images.where((img) {
      if (img.isEmpty) return false;
      final lower = img.toLowerCase();
      return !lower.endsWith('.mp4') &&
             !lower.endsWith('.mov') &&
             !lower.endsWith('.avi') &&
             !lower.endsWith('.3gp') &&
             !lower.endsWith('.mkv');
    }).toList();

    if (allImages.isNotEmpty) {
      Get.dialog(
        const Center(
          child: Card(
            color: Color(0xFF111122),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1877F2)),
                  SizedBox(height: 16),
                  Text(
                    'جاري تجهيز الصور للمشاركة...',
                    style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      try {
        for (final img in allImages) {
          if (img.startsWith('http')) {
            final res = await http.get(Uri.parse(img));
            if (res.statusCode == 200) {
              final tempDir = await getTemporaryDirectory();
              final fileName = img.split('/').last.split('?').first;
              final file = File('${tempDir.path}/$fileName');
              await file.writeAsBytes(res.bodyBytes);
              xFiles.add(sp.XFile(file.path));
            }
          } else {
            xFiles.add(sp.XFile(img));
          }
        }
      } catch (e) {
        debugPrint('Error downloading images for share: $e');
      }

      if (Get.isDialogOpen ?? false) Get.back();
    }

    try {
      if (xFiles.isNotEmpty) {
        await sp.SharePlus.instance.share(
          sp.ShareParams(files: xFiles, text: text),
        );
      } else {
        await sp.SharePlus.instance.share(sp.ShareParams(text: text));
      }
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر إتمام المشاركة: $e',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373));
    }
  }

  // ── الصور ──
  Widget _buildImagesSection() {
    return Obx(() => Column(
          children: [
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: ctrl.pickImages,
                    child: Obx(() => ctrl.isUploadingMedia.value
                        ? const SizedBox(
                            width: 90,
                            height: 90,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1877F2),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const _AddMediaButton(icon: Icons.add_a_photo_rounded)),
                  ),
                  const SizedBox(width: 10),
                  ...List.generate(ctrl.pickedImages.length, (i) {
                    final path = ctrl.pickedImages[i];
                    final isNetwork = path.startsWith('http');
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: i == 0
                                  ? const Color(0xFF1877F2)
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: isNetwork
                                ? CachedNetworkImage(
                                    imageUrl: path,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : kIsWeb
                                    ? Image.network(
                                        path,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white30),
                                        ),
                                      )
                                    : Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                        cacheWidth: 150,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white30),
                                        ),
                                      ),
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            bottom: -4,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'رئيسية',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontFamily: 'IBMPlexSansArabic'),
                              ),
                            ),
                          ),
                        Positioned(
                          top: -6,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => ctrl.removeImage(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            if (ctrl.pickedImages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'أضف صورة رئيسية للمنتج على الأقل',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ));
  }

  // ── الفيديو ──
  Widget _buildVideoSection() {
    return Obx(() {
      final hasVideo = ctrl.pickedVideoPath.value.isNotEmpty;
      return Row(
        children: [
          GestureDetector(
            onTap: ctrl.pickVideo,
            child: _AddMediaButton(
              icon: hasVideo ? Icons.videocam_rounded : Icons.video_call_rounded,
              color: hasVideo ? Colors.green : null,
            ),
          ),
          const SizedBox(width: 12),
          if (hasVideo)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.pickedVideoPath.value.split('/').last.split('\\').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: ctrl.removeVideo,
                    child: Text(
                      'إزالة',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'اختر فيديو للمنتج (اختياري)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
              ),
            ),
        ],
      );
    });
  }

  // ── AI ──
  Widget _buildAiSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'توليد وصف بالذكاء الاصطناعي',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'صوّر المنتج أو اختر صورته لتوليد العنوان والوصف والفئة تلقائياً',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AiButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'كاميرا',
                  onTap: () => _analyzeWithAi(ImageSource.camera),
                  isLoading: _isAnalyzing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AiButton(
                  icon: Icons.photo_library_rounded,
                  label: 'معرض الصور',
                  onTap: () => _analyzeWithAi(ImageSource.gallery),
                  isLoading: _isAnalyzing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeWithAi(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isAnalyzing = true);

      ctrl.pickedImages.insert(0, picked.path);
      final uid = ctrl.editingProduct.value?.id ?? Get.find<AuthController>().firebaseUid;
      if (uid != null) {
        final url = await Get.find<FirebaseStorageService>().uploadProductMedia(
          uid: uid,
          file: File(picked.path),
          mediaType: 'image',
        );
        if (url != null) ctrl.uploadedImageUrls.insert(0, url);
      }

      if (Get.isRegistered<UnifiedAIService>()) {
        final ai = Get.find<UnifiedAIService>();

        const catalogPrompt = """
أنت خبير تحليل منتجات للكتالوج التجاري.
انظر إلى هذه الصورة وأعطني المعلومات التالية بدقة شديدة.

قواعد إلزامية:
- جميع النصوص في الرد بالعربية فقط (ما عدا فئات Google وFacebook تبقى إنجليزية).
- لا تخترع معلومات غير موجودة في الصورة.
- إذا لم تجد معلومة اكتب: فارغ

أعد الرد بهذا الشكل الحرفي فقط:
===TITLE===
[اسم المنتج بالعربية - مختصر واحترافي]
===DESCRIPTION===
[اكتب وصفاً تسويقياً إعلانياً جذاباً واحترافياً للمنتج بالعربية بأسلوب منشور فيسبوك/تيك توك يجمع بين الخطاف القوي والفوائد والميزات الرائعة بشكل منسق مع الإيموجي المناسب وفواصل السطور، بدون أرقام هواتف أو معلومات تواصل أو روابط]
===BRAND===
[العلامة التجارية أو: فارغ]
===COLOR===
[اللون الرئيسي أو: فارغ]
===SIZE===
[المقاس أو الحجم أو: فارغ]
===PRICE===
[السعر بالريال اليمني كعدد رقمي فقط في حال كان مكتوباً أو معروفاً، أو: فارغ]
===SAR===
[السعر بالريال السعودي كعدد رقمي فقط في حال كان مكتوباً أو معروفاً، أو: فارغ]
===CATEGORY===
[اختر الفئة الرئيسية للمنتج من هذه القائمة فقط: المطبخ، التنظيم والتخزين، الجمال والعناية، الصحة والمساج، العدد والأدوات، السيارات، الرياضة واللياقة، الرحلات والخارجية، الأطفال والألعاب، الإلكترونيات، المنزل والديكور، الإضاءة والطاقة، الحيوانات الأليفة، متنوعات]
===G_CAT===
[فئة Google المناسبة بالإنجليزية مثل: Apparel & Accessories > Clothing أو: فارغ]
===FB_CAT===
[فئة Facebook المناسبة بالإنجليزية مثل: Clothing & Accessories > Clothing أو: فارغ]
===CONDITION===
[new أو used]
""";

        final imageFile = File(picked.path);
        final res = await ai.analyzeImage(imageFile, catalogPrompt);
        final rawResponse = res.description.trim();
        debugPrint('DEBUG: rawResponse from AI = "$rawResponse"');

        final Map<String, String> parsed = {};
        final regExp = RegExp(r'===(TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR|CATEGORY)===\s*([\s\S]*?)(?=\s*===(?:TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR|CATEGORY)===|$)');
        for (final match in regExp.allMatches(rawResponse)) {
          final key = match.group(1)!.toUpperCase();
          final val = match.group(2)!.trim();
          if (val.isNotEmpty && val != 'فارغ') {
            parsed[key] = val;
          }
        }
        debugPrint('DEBUG: parsed map = $parsed');

        if (mounted) {
          // 🔎 محرك المطابقة البرمجي (Hybrid Product Matching)
          final matchingService = Get.find<ProductMatchingService>();
          final matches = matchingService.findMatches(parsed, ctrl.products);

          if (matches.isNotEmpty && matches.first.score >= 0.60) {
            _showMatchingDecisionDialog(matches.first, parsed);
          } else {
            _populateFields(parsed);
            Get.snackbar(
              '✅ تم التحليل',
              'تم ملء الحقول واستخراج البيانات والسعر تلقائياً!',
              backgroundColor: const Color(0xFF1A3A1A),
              colorText: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ AI analyze error: $e');
      if (mounted) {
        Get.snackbar(
          '❌ خطأ في التحليل',
          'تعذّر تحليل الصورة، حاول مرة أخرى.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _populateFields(Map<String, String> parsed) {
    setState(() {
      final title = parsed['TITLE'] ?? '';
      if (title.isNotEmpty) _titleCtrl.text = title;

      final desc = parsed['DESCRIPTION'] ?? '';
      if (desc.isNotEmpty) _descCtrl.text = desc;

      final brand = parsed['BRAND'] ?? '';
      if (brand.isNotEmpty && _brandCtrl.text.isEmpty) _brandCtrl.text = brand;

      final color = parsed['COLOR'] ?? '';
      if (color.isNotEmpty && _colorCtrl.text.isEmpty) _colorCtrl.text = color;

      final size = parsed['SIZE'] ?? '';
      if (size.isNotEmpty && _sizeCtrl.text.isEmpty) _sizeCtrl.text = size;

      final price = parsed['PRICE'] ?? '';
      if (price.isNotEmpty && _priceCtrl.text.isEmpty) _priceCtrl.text = price;

      final aiCat = parsed['CATEGORY'] ?? '';
      if (aiCat.isNotEmpty) {
        final matched = allProductCategories.firstWhereOrNull(
          (c) => c.name.trim() == aiCat.trim() || c.id == aiCat.trim()
        );
        if (matched != null) {
          _categoryId = matched.id;
        }
      }

      final gCat = parsed['G_CAT'] ?? '';
      if (gCat.isNotEmpty) {
        _gCategoryCtrl.text = gCat;
      } else if (_categoryId != null) {
        final matched = allProductCategories.firstWhereOrNull((c) => c.id == _categoryId);
        if (matched != null && _gCategoryCtrl.text.isEmpty) {
          _gCategoryCtrl.text = matched.googleCategory;
        }
      }

      final fbCat = parsed['FB_CAT'] ?? '';
      if (fbCat.isNotEmpty) {
        _fbCategoryCtrl.text = fbCat;
      } else if (_categoryId != null) {
        final matched = allProductCategories.firstWhereOrNull((c) => c.id == _categoryId);
        if (matched != null && _fbCategoryCtrl.text.isEmpty) {
          _fbCategoryCtrl.text = matched.fbCategory;
        }
      }

      final cond = parsed['CONDITION'] ?? '';
      if (cond == 'used') _condition = 'used';
    });
  }

  void _showMatchingDecisionDialog(ProductMatchingResult match, Map<String, String> parsed) {
    final existingProduct = match.product;
    final matchScorePercent = (match.score * 100).toStringAsFixed(0);
    final classification = match.classification;
    final isExact = classification == MatchClassification.exactMatch;
    
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF111122),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isExact ? Icons.warning_amber_rounded : Icons.info_outline,
              color: isExact ? Colors.amber : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              isExact ? '🔎 تم العثور على منتج مطابق!' : '💡 منتج مشابه متوفر',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نسبة التشابه: $matchScorePercent%',
                style: TextStyle(
                  color: isExact ? Colors.amber : Colors.blueAccent,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'السبب: ${match.reason}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'المنتج الحالي في الكتالوج:',
                style: TextStyle(
                  color: Colors.white30,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (existingProduct.imageLink.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: existingProduct.imageLink.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: existingProduct.imageLink,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : kIsWeb
                                ? Image.network(
                                    existingProduct.imageLink,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white30, size: 20),
                                  )
                                : Image.file(
                                    File(existingProduct.imageLink),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    cacheWidth: 100,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white30, size: 20),
                                  ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existingProduct.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            existingProduct.formattedPrice,
                            style: const TextStyle(
                              color: Color(0xFF1877F2),
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ماذا تريد أن تفعل؟',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back();
              final matchingService = Get.find<ProductMatchingService>();
              await matchingService.saveMatchDecision(
                productId: existingProduct.id,
                decision: 'cancel',
                similarityScore: match.score,
                reason: match.reason,
              );
              ctrl.resetForm();
            },
            child: const Text('إلغاء 🚫', style: TextStyle(color: Colors.white30, fontFamily: 'IBMPlexSansArabic')),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final matchingService = Get.find<ProductMatchingService>();
              await matchingService.saveMatchDecision(
                productId: existingProduct.id,
                decision: 'create_new',
                similarityScore: match.score,
                reason: match.reason,
              );
              _populateFields(parsed);
              Get.snackbar(
                '💡 تم التجاوز',
                'تم تعبئة الحقول لإضافة المنتج كمنتج جديد مستقل.',
                backgroundColor: const Color(0xFF1A2A3A),
                colorText: Colors.white,
                duration: const Duration(seconds: 4),
              );
            },
            child: const Text('إنشاء جديد ➕', style: TextStyle(color: Colors.blueAccent, fontFamily: 'IBMPlexSansArabic')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
            onPressed: () async {
              Get.back();
              final matchingService = Get.find<ProductMatchingService>();
              await matchingService.saveMatchDecision(
                productId: existingProduct.id,
                decision: 'merge',
                similarityScore: match.score,
                reason: match.reason,
              );
              await ctrl.mergeProductImages(existingProduct, ctrl.pickedImages, ctrl.uploadedImageUrls);
              Get.back();
            },
            child: const Text('دمج الصور 🔗', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Get.back();
              final matchingService = Get.find<ProductMatchingService>();
              await matchingService.saveMatchDecision(
                productId: existingProduct.id,
                decision: 'update',
                similarityScore: match.score,
                reason: match.reason,
              );
              await ctrl.updateProductWithAiData(existingProduct, parsed, ctrl.pickedImages, ctrl.uploadedImageUrls);
              Get.back();
            },
            child: const Text('تحديث الحقول ✏️', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _optimizeDescriptionWithAi() async {
    final rawText = _descCtrl.text.trim();
    if (rawText.isEmpty) {
      Get.snackbar(
        '⚠️ الوصف فارغ',
        'الرجاء كتابة أو لصق نص الوصف أولاً ليتم تنظيمه وتحديد السعر تلقائياً.',
        backgroundColor: const Color(0xFF3A251A),
        colorText: const Color(0xFFFFB74D),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isOptimizingDesc = true);

    try {
      final medicalKeywords = [
        'جهاز طبي', 'medical device', 'ضغط الدم', 'blood pressure',
        'جلوكوز', 'glucose', 'ecg', 'نبض القلب',
        'oximeter', 'أكسجين الدم', 'oxygen', 'مستشفى', 'hospital',
        'تشخيص طبي', 'diagnosis', 'علاج طبي', 'دواء طبي', 'medicine',
        'أشعة x', 'x-ray', 'موجات فوق صوتية', 'ultrasound', 'منظار طبي', 'endoscope',
        'عملية جراحية', 'surgery', 'عيادة طبية', 'مريض طبي',
        'مختبر طبي', 'laboratory test', 'فحص طبي', 'ترمومتر طبي',
        'stethoscope', 'سماعة طبية', 'حقنة طبية', 'syringe', 'medical needle',
        'إبرة طبية', 'insulin', 'أنسولين', 'كولسترول', 'cholesterol',
      ];
      final lowerRawText = rawText.toLowerCase();
      final isMedicalDevice = medicalKeywords.any((kw) => lowerRawText.contains(kw.toLowerCase()));

      if (isMedicalDevice) {
        if (mounted) {
          Get.dialog(
            AlertDialog(
              backgroundColor: const Color(0xFF1A0A0A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.red, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.medical_services_rounded, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🚫 تحذير: جهاز طبي محظور!',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'تم اكتشاف أن هذا المنتج قد يكون جهازاً طبياً أو منتجاً صحياً.\n\n'
                '❌ منصة Meta ترفض هذه المنتجات وتحذف الكتالوج بأكمله عند إضافتها.\n\n'
                '⚠️ لا يمكن إكمال عملية حفظ هذا المنتج.\n\n'
                'إذا كان المنتج غير طبي، يرجى مراجعة الوصف وحذف أي كلمات طبية منه.',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'حسناً، سأعدّل الوصف',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      String cleanedText = rawText;
      cleanedText = cleanedText.replaceAll(
        RegExp(r'(\+?967|00967)?[\s\-]?(7\d{8}|\d{3}[\s\-]?\d{3}[\s\-]?\d{4})'),
        '',
      );
      cleanedText = cleanedText.replaceAll(
        RegExp(r'اندكس\s*ستور|index\s*store|متجر\s*اندكس|للتواصل|للاستفسار|واتساب|whatsapp', caseSensitive: false),
        '',
      );
      cleanedText = cleanedText.replaceAll(
        RegExp(r'(للطلب|للتواصل|للاستفسار|تواصل معنا|اتصل بنا|راسلنا)[^\n]*\n?', caseSensitive: false),
        '',
      );
      cleanedText = cleanedText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      final prompt = """
تصرّف كخبير تسويق وتنظيم أوصاف منتجات.

سأرسل لك وصف منتج جاهز يحتوي على كلام غير مرتب + مميزات + سعر أو أكثر.
مهمتك تنفيذ الخطوات التالية بدقة شديدة دون إضافة أو اختراع أي معلومة جديدة.

⚠️ شروط إلزامية عامة:
- جميع الكلمات في الناتج النهائي تكون بدون أي علامات تشكيل (بدون حركات نهائيًا)
- استخرج السعر وطبق معادلة السعر المحددة بالأسفل.
- حدد فئة المنتج المناسبة لـ Google Product Category و Facebook Product Category.
- استخرج السمات الأخرى (الشركة المصنعة/العلامة التجارية، اللون، المقاس) إن وجدت.
- احذف تلقائياً أي أرقام هواتف أو معلومات تواصل أو أسماء متاجر من الوصف النهائي.
- احذف أي عبارات مثل "للتواصل"، "للطلب"، "واتساب"، "أرقام تليفون" من الوصف نهائياً.

المهمة الأولى: العنوان والهوك
1. أنشئ عنوانًا احترافيًا مختصرًا (Hook):
   - جذاب ومناسب للبيع
   - مستخرج من نفس الوصف فقط
2. تحت العنوان مباشرة:
   - ضع أهم وأقوى ميزة واحدة فقط تشد الانتباه.

المهمة الثانية: اعادة الصياغة والتنظيم للوصف
1. اعد صياغة الوصف ليكون مرتب، واضح، ومخترص.
2. يمنع منعًا باتًا اضافة اي معلومة جديدة او اختراع مميزات غير موجودة.
3. احذف اي كلام مكرر، غير مهم، او انشائي بلا فائدة.
4. استخرج مميزات المنتج فقط كقائمة نقاط واضحة.

المهمة الثالثة: معالجة السعر
1. اذا وجد سعر خاص بـ "الجنوب" → احذفه نهائيًا وتجاهله.
2. اذا وجد اكثر من سعر: اختر اقل سعر فقط.
3. طبق الزيادة على السعر المستخرج بالريال اليمني (YER) حسب الشرائح التالية:
   - من 500 الى 2500 ريال يمني ➜ اضف 1900
   - اكثر من 3000 الى 10000 ريال يمني ➜ اضف 2900
   - 10000 ريال يمني او اكثر ➜ اضف 3900
4. بعد الحساب والزيادة: حول السعر الناتج إلى رقم نفسي ينتهي بـ 900 (مثال: 6000 يصبح 5900، 7200 يصبح 6900، 10000 يصبح 9900، 12000 يصبح 11900 وهكذا).

المهمة الرابعة: التحويل للعملات
1. احسب السعر بالريال السعودي (SAR) بناءً على السعر النهائي بالريال اليمني بعد الزيادة والتقريب النفسي:
   - التحويل يكون على الأساس: 1 ريال سعودي = 140 ريال يمني (أي اقسم السعر اليمني على 140).
   - احذف الكسور تمامًا واكتب الرقم الصحيح فقط للسعودي.

أرجع النتيجة بالصيغة النصية التالية بدقة بالغة وبنفس الترتيب دائماً. يجب كتابة كل قسم، وإذا لم تجد قيمته اكتب: فارغ

===TITLE===
[العنوان المستخرج بدون حركات، أو: فارغ]
===HOOK===
[الهوك/الميزة القوية بدون حركات، أو: فارغ]
===BODY===
[اكتب وصفاً تسويقياً إعلانياً جذاباً واحترافياً ومفصلاً للمنتج بالعربية بأسلوب منشور فيسبوك/تيك توك يجمع بين الفوائد والميزات الرائعة بشكل منسق مع الإيموجي المناسب وفواصل السطور، بدون حركات وبدون أرقام هواتف، أو: فارغ]
===FEATURES===
[ميزة 1 بدون حركات، ميزة 2 بدون حركات، أو: فارغ]
===PRICE===
[السعر اليمني النهائي كعدد رقمي فقط، أو: فارغ]
===SAR===
[السعر السعودي النهائي كعدد رقمي فقط، أو: فارغ]
===G_CAT===
[فئة جوجل المناسبة للمنتج بالإنجليزية، مثل: Apparel & Accessories > Clothing، أو: فارغ]
===FB_CAT===
[فئة فيسبوك المناسبة للمنتج بالإنجليزية، مثل: Apparel & Accessories > Clothing، أو: فارغ]
===BRAND===
[الماركة، أو: فارغ]
===COLOR===
[اللون، أو: فارغ]
===SIZE===
[المقاس، أو: فارغ]

النص المراد تحليله:
$cleanedText
""";

      if (Get.isRegistered<UnifiedAIService>()) {
        final ai = Get.find<UnifiedAIService>();
        final response = await ai.generateText(prompt);
        final rawResponse = response.trim();
        debugPrint('DEBUG OPTIMIZE: rawResponse = "$rawResponse"');
        
        final Map<String, String> parsed = {};
        final regExp = RegExp(r'===(TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR)===\s*([\s\S]*?)(?=\s*===(?:TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR)===|$)');
        for (final match in regExp.allMatches(rawResponse)) {
          final key = match.group(1)!.toUpperCase();
          final val = match.group(2)!.trim();
          if (val.isNotEmpty && val != 'فارغ' && val != 'empty') {
            parsed[key] = val;
          }
        }
        debugPrint('DEBUG OPTIMIZE: parsed map = $parsed');

        if (mounted) {
          final titleStr = parsed['TITLE'] ?? '';
          final hookStr = parsed['HOOK'] ?? '';
          final rephrasedBody = parsed['BODY'] ?? '';
          final featuresText = parsed['FEATURES'] ?? '';
          final priceYer = parsed['PRICE'] ?? '';
          final priceSar = parsed['SAR'] ?? '';
          final gCatRaw = parsed['G_CAT'] ?? '';
          final fbCatRaw = parsed['FB_CAT'] ?? '';
          final brand = parsed['BRAND'] ?? '';
          final color = parsed['COLOR'] ?? '';
          final size = parsed['SIZE'] ?? '';

          String formattedDesc = '';
          if (titleStr.isNotEmpty) formattedDesc += '$titleStr\n';
          if (hookStr.isNotEmpty) formattedDesc += '$hookStr\n';
          if (formattedDesc.isNotEmpty) formattedDesc += '\n';
          if (rephrasedBody.isNotEmpty) formattedDesc += '$rephrasedBody\n\n';
          
          if (featuresText.isNotEmpty) {
            final fLines = featuresText.split('\n');
            for (final fl in fLines) {
              final line = fl.trim();
              if (line.isNotEmpty) {
                formattedDesc += '✅ ${line.replaceAll('✅', '').trim()}\n';
              }
            }
            formattedDesc += '\n';
          }
          
          if (priceYer.isNotEmpty) {
            formattedDesc += 'السعر: $priceYer ريال يمني\n';
          }
          if (priceSar.isNotEmpty) {
            formattedDesc += 'ما يعادل: $priceSar ريال سعودي';
          }

          setState(() {
            _titleCtrl.text = titleStr.isNotEmpty 
                ? (hookStr.isNotEmpty ? '$titleStr - $hookStr' : titleStr) 
                : _titleCtrl.text;
            _descCtrl.text = formattedDesc;
            
            if (priceYer.isNotEmpty) {
              _priceCtrl.text = priceYer;
            }
            
            final gCat = gCatRaw;
            if (gCat.isNotEmpty) _gCategoryCtrl.text = gCat;
            
            final fbCat = fbCatRaw;
            if (fbCat.isNotEmpty) _fbCategoryCtrl.text = fbCat;
            
            if (brand.isNotEmpty && _brandCtrl.text.isEmpty) _brandCtrl.text = brand;
            if (color.isNotEmpty && _colorCtrl.text.isEmpty) _colorCtrl.text = color;
            if (size.isNotEmpty && _sizeCtrl.text.isEmpty) _sizeCtrl.text = size;
          });

          Get.snackbar(
            '✨ اكتمل التحسين والتسعير',
            'تمت إعادة الصياغة وتحديث حقول السعر والفئة والخصائص تلقائياً!',
            backgroundColor: const Color(0xFF1A3A1A),
            colorText: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Description optimization error: $e');
      Get.snackbar(
        '❌ خطأ في معالجة الوصف',
        'حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isOptimizingDesc = false);
      }
    }
  }

  String _cleanCategory(String s) {
    String res = s.trim();
    while (res.startsWith('>') || res.startsWith('<') || res.startsWith('-') || res.startsWith('/') || res.startsWith('.')) {
      res = res.substring(1).trim();
    }
    return res;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (ctrl.pickedImages.isEmpty) {
      Get.snackbar(
        '⚠️ الصورة مطلوبة',
        'يجب إضافة صورة واحدة على الأقل للمنتج ليتم قبوله ومزامنته في Meta Commerce.',
        backgroundColor: const Color(0xFF3A251A),
        colorText: const Color(0xFFFFB74D),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() => _isSaving = true);

    Get.dialog(
      const Center(
        child: Card(
          color: Color(0xFF111122),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1877F2)),
                SizedBox(height: 16),
                Text(
                  'جاري حفظ المنتج...',
                  style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final product = CatalogProduct(
        id: widget.editProduct?.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        availability: _availability,
        condition: _condition,
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        currency: _currency,
        link: _linkCtrl.text.trim(),
        brand: _brandCtrl.text.trim().isNotEmpty ? _brandCtrl.text.trim() : null,
        googleProductCategory: _gCategoryCtrl.text.trim().isNotEmpty
            ? _cleanCategory(_gCategoryCtrl.text.trim())
            : null,
        fbProductCategory: _fbCategoryCtrl.text.trim().isNotEmpty
            ? _cleanCategory(_fbCategoryCtrl.text.trim())
            : null,
        categoryId: _categoryId,
        categoryName: allProductCategories.firstWhereOrNull((e) => e.id == _categoryId)?.name,
        metaProductType: allProductCategories.firstWhereOrNull((e) => e.id == _categoryId)?.fbCategory,
        quantity: int.tryParse(_quantityCtrl.text.trim()) ?? 1,
        color: _colorCtrl.text.trim().isNotEmpty ? _colorCtrl.text.trim() : null,
        size: _sizeCtrl.text.trim().isNotEmpty ? _sizeCtrl.text.trim() : null,
        creatorUid: widget.editProduct?.creatorUid,
        status: Get.find<AuthController>().isAdmin ? _status : 'approved',
      );

      await ctrl.saveProduct(product);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar(
        '❌ خطأ في الحفظ',
        e.toString(),
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic'),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontFamily: 'IBMPlexSansArabic',
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontFamily: 'IBMPlexSansArabic',
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1877F2), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1A1A2E),
      style: const TextStyle(
          color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
    );
  }

  // ── إدارة الفئات المخصصة ──

  void _showManageCategoriesDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF0D0D1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🗂️ إدارة فئات المنتجات',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddEditCategoryDialog(null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'إضافة فئة جديدة',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  final allCats = ctrl.allCategories;
                  return ListView.builder(
                    itemCount: allCats.length,
                    itemBuilder: (context, index) {
                      final c = allCats[index];
                      final isPredefined = predefinedCategories.any((p) => p.id == c.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'جوجل: ${c.googleCategory.split(" > ").last}\nفيسبوك: ${c.fbCategory.split(" > ").last}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 11,
                            ),
                          ),
                          trailing: isPredefined
                              ? const Tooltip(
                                  message: 'فئة نظام افتراضية (غير قابلة للحذف)',
                                  child: Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 18),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 18),
                                      onPressed: () => _showAddEditCategoryDialog(c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                      onPressed: () => _confirmDeleteCategory(c),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditCategoryDialog(ProductCategoryInfo? existingCat) {
    final nameCtrl = TextEditingController(text: existingCat?.name ?? '');
    final googleCtrl = TextEditingController(
      text: existingCat?.googleCategory ?? 'Home & Garden',
    );
    final fbCtrl = TextEditingController(
      text: existingCat?.fbCategory ?? 'Home & Garden',
    );
    final isEdit = existingCat != null;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? '✏️ تعديل الفئة المخصصة' : '➕ إضافة فئة مخصصة جديدة',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              _buildDialogField(ctrl: nameCtrl, label: 'اسم الفئة (مثال: 👕 ملابس)', hint: 'أدخل الاسم مع رمز تعبيري إن أردت'),
              const SizedBox(height: 12),
              _buildDialogField(ctrl: googleCtrl, label: 'مسار فئة جوجل للتسوق', hint: 'Home & Garden > ...'),
              const SizedBox(height: 12),
              _buildDialogField(ctrl: fbCtrl, label: 'مسار فئة فيسبوك للتسوق', hint: 'Home & Garden > ...'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'IBMPlexSansArabic')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94560),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final gCat = googleCtrl.text.trim();
                      final fbCat = fbCtrl.text.trim();

                      if (name.isEmpty) {
                        Get.snackbar('⚠️ تنبيه', 'الاسم مطلوب لإنشاء الفئة',
                            backgroundColor: const Color(0xFF3D2E1F), colorText: const Color(0xFFFFE0B2));
                        return;
                      }

                      final catId = isEdit ? existingCat.id : 'cat_${DateTime.now().millisecondsSinceEpoch}';
                      final newCat = ProductCategoryInfo(
                        id: catId,
                        name: name,
                        googleCategory: gCat.isNotEmpty ? gCat : 'Home & Garden',
                        fbCategory: fbCat.isNotEmpty ? fbCat : 'Home & Garden',
                      );

                      if (isEdit) {
                        ctrl.updateCustomCategory(catId, newCat);
                      } else {
                        ctrl.addCustomCategory(newCat);
                      }
                      Get.back(); // إغلاق نافذة الإضافة/التعديل
                    },
                    child: Text(
                      isEdit ? 'حفظ التعديل' : 'إضافة',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0D0D1A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteCategory(ProductCategoryInfo cat) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('⚠️ حذف الفئة المخصصة', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic')),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف فئة "${cat.name}"؟ سيتم إعادة تعيين المنتجات المرتبطة بها للفئة الافتراضية.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'IBMPlexSansArabic')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ctrl.deleteCustomCategory(cat.id);
              if (_categoryId == cat.id) {
                setState(() {
                  _categoryId = 'other';
                });
              }
              Get.back();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'IBMPlexSansArabic',
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const _AddMediaButton({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? Colors.white).withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Icon(icon, color: color ?? Colors.white.withValues(alpha: 0.4), size: 32),
    );
  }
}



class _AiButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _AiButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                  )
                : Icon(icon, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primary,
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
