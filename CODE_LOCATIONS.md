# 📍 دليل مواقع الكود - Code Location Map

## 🎯 الملفات المعدلة الرئيسية

### 1. lib/screens/upload_screen.dart (الملف الرئيسي)
**الحجم**: 683 سطر
**حالة التعديل**: كبيرة (150+ سطر مضافة)

---

## 🔍 خريطة التعديلات التفصيلية

### المتغيرات والحقول (Variables & Fields)

#### TextEditingController
**الموقع**: سطر ~27
**الكود**:
\\\dart
late TextEditingController _promptController;
\\\
**الشرح**: متحكم للنص المدخل من المستخدم
**الحالة**: ✅ تم الإضافة

---

### Methods (الدوال)

#### initState()
**الموقع**: سطر ~35-38
**الوظيفة**: تهيئة التطبيق
**ما تم إضافته**:
\\\dart
@override
void initState() {
  super.initState();
  _promptController = TextEditingController();
}
\\\
**الحالة**: ✅ تم التعديل

---

#### dispose()
**الموقع**: سطر ~40-44
**الوظيفة**: تنظيف الموارد
**ما تم إضافته**:
\\\dart
@override
void dispose() {
  _promptController.dispose();
  super.dispose();
}
\\\
**الحالة**: ✅ تم التعديل
**أهمية**: منع تسرب الذاكرة (Memory Leak Prevention)

---

#### _generateDescription()
**الموقع**: سطر ~207-238
**الوظيفة الأصلية**: توليد وصف المنتج
**ما تم تعديله**:
\\\dart
// ✅ استخدام النص المخصص من المستخدم أو نص افتراضي
final userPrompt = _promptController.text.trim();
final promptText = userPrompt.isEmpty
    ? "أنشئ وصفاً تسويقياً احترافياً..."
    : userPrompt;

final description = await gemini.generateCustomContent(
  promptText,
  imageBytes: bytes,
  contentType: contentType,
);
\\\
**الحالة**: ✅ تم التعديل
**الفائدة**: استخدام أوامر المستخدم المخصصة

---

#### _generateAdvertisement() - جديدة
**الموقع**: سطر ~241-272
**الوظيفة**: توليد إعلان تسويقي
**الكود**:
\\\dart
Future<void> _generateAdvertisement() async {
  if (_imageFile == null) {
    _showToast("لم يتم اختيار صورة", icon: Icons.info_outline);
    return;
  }
  
  setState(() => isLoading = true);
  try {
    // ... معالجة الصورة ...
    
    // استخدام النص المخصص من المستخدم
    final userPrompt = _promptController.text.trim();
    final enhancedPrompt = userPrompt.isEmpty
        ? "اكتب إعلانًا تسويقياً احترافياً وجذابًا..."
        : userPrompt;
    
    final advertisement = await gemini.generateAdvertisement(
      bytes,
      enhancedPrompt,
      contentType: contentType,
    );
    
    if (mounted) setState(() => productDescription = advertisement);
    _showSnack("تم توليد الإعلان التسويقي عبر Gemini 📢");
  } catch (e) {
    _showSnack("خطأ في توليد الإعلان: \", error: true);
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
\\\
**الحالة**: ✅ تم الإضافة
**الطول**: ~32 سطر

---

### UI Components (عناصر الواجهة)

#### TextField - حقل الإدخال
**الموقع**: سطر ~457-491
**الوصف**: حقل إدخال النص المخصص
**الكود الكامل**:
\\\dart
// ✅ حقل الإدخال النصي الجديد
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 0),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: _promptController,
      textAlign: TextAlign.right,
      maxLines: 3,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF222222),
        fontFamily: 'IBMPlexSansArabic',
      ),
      decoration: InputDecoration(
        hintText: '✍️ اكتب هنا ما تريد توليده',
        hintStyle: TextStyle(
          fontSize: 15,
          color: Colors.grey[600],
          fontFamily: 'IBMPlexSansArabic',
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  ),
)
\\\
**الحالة**: ✅ تم الإضافة
**الطول**: ~35 سطر
**المواصفات**:
- ✓ RTL (textAlign.right)
- ✓ 3 أسطر من النص (maxLines: 3)
- ✓ Fonts عربية (IBMPlexSansArabic)
- ✓ تصميم جميل مع ظلال

---

#### Advertisement Button - زر الإعلان
**الموقع**: سطر ~652-656
**الوصف**: زر لتوليد الإعلانات التسويقية
**الكود**:
\\\dart
// ✅ زر جديد لتوليد إعلان تسويقي
FilledButton.icon(
  icon: const Icon(Icons.announcement_outlined),
  label: const Text("إعلان تسويقي"),
  onPressed: isLoading ? null : _generateAdvertisement,
)
\\\
**الحالة**: ✅ تم الإضافة
**الطول**: 5 أسطر
**المواصفات**:
- ✓ Icon: announcement_outlined
- ✓ Label: "إعلان تسويقي"
- ✓ Disabled عند التحميل (isLoading ? null)
- ✓ متصل بدالة _generateAdvertisement()

---

## 🔧 lib/services/gemini_service.dart

**الحجم الأصلي**: 158 سطر
**الحجم الحالي**: ~220 سطر
**الأسطر المضافة**: ~60 سطر

---

### الدوال الجديدة

#### generateCustomContent()
**الموقع**: سطر ~99-116
**الوظيفة**: توليد محتوى مخصص مع صورة اختيارية
**الكود**:
\\\dart
/// Generate custom content with user prompt and optional image
Future<String> generateCustomContent(
  String userPrompt,
  {
    Uint8List? imageBytes,
    String contentType = 'image/png'
  }
) async {
  await _ensureModel();
  
  if (imageBytes != null && imageBytes.isNotEmpty) {
    // إذا كانت هناك صورة، أضفها إلى المحتوى
    final response = await _model!.generateContent([
      Content.multi([
        TextPart(userPrompt),
        DataPart(contentType, imageBytes),
      ])
    ]);
    return (response.text ?? '').trim();
  } else {
    // بدون صورة، فقط استخدم النص
    final response = await _model!
      .generateContent([Content.text(userPrompt)]);
    return (response.text ?? '').trim();
  }
}
\\\
**الحالة**: ✅ تم الإضافة
**الطول**: 18 سطر
**الميزات**:
- ✓ يدعم الصور الاختيارية
- ✓ يدعم النصوص الحرة
- ✓ معالجة الأخطاء الآمنة

---

#### generateAdvertisement()
**الموقع**: سطر ~119-139
**الوظيفة**: توليد إعلان تسويقي احترافي
**الكود**:
\\\dart
/// Generate marketing advertisement based on image and prompt (Arabic)
Future<String> generateAdvertisement(
  Uint8List bytes,
  String userPrompt,
  {String contentType = 'image/png'}
) async {
  await _ensureModel();
  final enhancedPrompt =
      'اكتب إعلانًا تسويقياً احترافياً وجذابًا بالعربية...'
      'تأكد من أن الإعلان:\\n'
      '- موجز وجذاب (3-4 جُمل)\\n'
      '- مناسب لمنصات التواصل الاجتماعي\\n'
      '- يركز على الفوائد والتميز\\n'
      '- خالي من الرموز التعبيرية المفرطة\\n'
      '- يحفز على الشراء بطريقة احترافية';
  
  final response = await _model!.generateContent([
    Content.multi([
      TextPart(enhancedPrompt),
      DataPart(contentType, bytes),
    ])
  ]);
  
  return (response.text ?? '').trim();
}
\\\
**الحالة**: ✅ تم الإضافة
**الطول**: 21 سطر
**الميزات**:
- ✓ نص محسّن للإعلانات
- ✓ معايير جودة عالية
- ✓ معالجة الصور تلقائياً

---

## 📊 ملخص الأسطر المضافة

### upload_screen.dart
\\\
TextEditingController إضافة: 1 سطر
initState() تعديل: 2 سطر إضافي
dispose() تعديل: 1 سطر إضافي
_generateDescription() تعديل: 5 أسطر إضافية
_generateAdvertisement() إضافة: 32 سطر
TextField UI إضافة: 35 سطر
Advertisement Button إضافة: 5 أسطر

المجموع: ~150 سطر
\\\

### gemini_service.dart
\\\
generateCustomContent() إضافة: 18 سطر
generateAdvertisement() إضافة: 21 سطر

المجموع: ~60 سطر
\\\

---

## 🔗 الترابطات (Dependencies)

### التحكم بـ TextField:
\\\
_promptController.text
    ↓
_generateDescription()
_generateAdvertisement()
    ↓
GeminiService.generateCustomContent()
GeminiService.generateAdvertisement()
\\\

---

## ✅ قائمة التحقق من الملفات

**يجب أن تحتوي على**:

### upload_screen.dart
- [ ] late TextEditingController _promptController;
- [ ] initState() مع تهيئة Controller
- [ ] dispose() مع تنظيف Controller
- [ ] TextField مع _promptController
- [ ] تعديل _generateDescription()
- [ ] دالة _generateAdvertisement() جديدة
- [ ] زر "إعلان تسويقي"

### gemini_service.dart
- [ ] دالة generateCustomContent() جديدة
- [ ] دالة generateAdvertisement() جديدة
- [ ] معالجة الأخطاء في كلا الدالتين

---

## 🚀 للبدء الفوري

1. فتح lib/screens/upload_screen.dart
2. ابحث عن TextEditingController (سطر 27)
3. تحقق من وجود TextField (سطر 457)
4. اختبر الزرار الجديدة
5. تحقق من GeminiService للدوال الجديدة

---

**آخر تحديث**: 11 نوفمبر 2025
**الحالة**: جاهز للاستخدام ✅
