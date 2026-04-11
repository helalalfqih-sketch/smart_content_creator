# 💻 أمثلة الكود - مرجع سريع

## 1️⃣ إضافة TextEditingController

### في رأس الكلاس _UploadScreenState
\\\dart
class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  // المتغيرات القديمة
  XFile? _imageFile;
  Uint8List? imageBytes;
  final ImagePicker _picker = ImagePicker();

  // ✅ متغير جديد
  late TextEditingController _promptController;

  // ... باقي المتغيرات
}
\\\

### في initState()
\\\dart
@override
void initState() {
  super.initState();
  // ✅ إضافة هذا السطر
  _promptController = TextEditingController();
}
\\\

### في dispose()
\\\dart
@override
void dispose() {
  // ✅ إضافة هذا السطر - مهم جداً!
  _promptController.dispose();
  super.dispose();
}
\\\

---

## 2️⃣ حقل الإدخال النصي (TextField)

### في build() - بعد صورة المنتج مباشرة
\\\dart
// في SingleChildScrollView → Column
children: [
  _imageCard(),
  const SizedBox(height: 20),

  // ✅ حقل الإدخال الجديد
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
          hintText: '✍️ اكتب هنا ما تريد توليده (مثلاً: اصنع لي وصف تسويقي لعطر Royal Blue)',
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
  ),
  const SizedBox(height: 20),

  // بقية الواجهة...
]
\\\

---

## 3️⃣ دالة توليد الوصف المحدثة

\\\dart
Future<void> _generateDescription() async {
  if (_imageFile == null) {
    _showToast("لم يتم اختيار صورة", icon: Icons.info_outline);
    return;
  }

  setState(() => isLoading = true);
  try {
    Uint8List bytes;
    String contentType = 'image/jpeg';
    
    // قراءة الصورة
    if (kIsWeb) {
      if (imageBytes == null) return;
      bytes = imageBytes!;
      final mt = lookupMimeType(_imageFile!.name);
      if (mt != null) contentType = mt;
    } else {
      final file = File(_imageFile!.path);
      bytes = await file.readAsBytes();
      final mt = lookupMimeType(_imageFile!.path, headerBytes: bytes);
      if (mt != null) contentType = mt;
    }

    // ✅ قراءة النص المخصص من المستخدم
    final userPrompt = _promptController.text.trim();
    
    // ✅ استخدام نص افتراضي إذا كان فارغاً
    final promptText = userPrompt.isEmpty
        ? "أنشئ وصفاً تسويقياً احترافياً وجذاباً للمنتج في هذه الصورة. اجعله موجزاً (3-5 جُمل) مناسباً لمتجر إلكتروني."
        : userPrompt;

    // ✅ استدعاء الدالة الجديدة مع الصورة والنص
    final description = await gemini.generateCustomContent(
      promptText,
      imageBytes: bytes,
      contentType: contentType,
    );

    if (mounted) setState(() => productDescription = description);
    _showSnack("تم توليد الوصف التسويقي عبر Gemini ✨");
  } catch (e) {
    _showSnack("خطأ في توليد الوصف: \", error: true);
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
\\\

---

## 4️⃣ دالة جديدة - توليد الإعلان التسويقي

\\\dart
// ✅ دالة جديدة تماماً
Future<void> _generateAdvertisement() async {
  if (_imageFile == null) {
    _showToast("لم يتم اختيار صورة", icon: Icons.info_outline);
    return;
  }

  setState(() => isLoading = true);
  try {
    Uint8List bytes;
    String contentType = 'image/jpeg';
    
    // قراءة الصورة
    if (kIsWeb) {
      if (imageBytes == null) return;
      bytes = imageBytes!;
      final mt = lookupMimeType(_imageFile!.name);
      if (mt != null) contentType = mt;
    } else {
      final file = File(_imageFile!.path);
      bytes = await file.readAsBytes();
      final mt = lookupMimeType(_imageFile!.path, headerBytes: bytes);
      if (mt != null) contentType = mt;
    }

    // ✅ قراءة النص المخصص
    final userPrompt = _promptController.text.trim();
    
    // ✅ بناء النص النهائي
    final enhancedPrompt = userPrompt.isEmpty
        ? "اكتب إعلانًا تسويقياً احترافياً وجذابًا بالعربية لهذا المنتج."
        : "اكتب إعلانًا تسويقياً احترافياً وجذابًا بالعربية. طلب العميل: \";

    // ✅ استدعاء الدالة المتخصصة للإعلانات
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

---

## 5️⃣ الزر الجديد في الواجهة

\\\dart
// بين أزرار الأخرى في Wrap
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: [
    // الزر الأول - توليد وصف
    FilledButton.icon(
      icon: const Icon(Icons.text_snippet_outlined),
      label: const Text("توليد وصف"),
      onPressed: isLoading ? null : _generateDescription,
    ),

    // ✅ الزر الجديد - إعلان تسويقي
    FilledButton.icon(
      icon: const Icon(Icons.announcement_outlined),
      label: const Text("إعلان تسويقي"),
      onPressed: isLoading ? null : _generateAdvertisement,
    ),

    // الزر الثالث - توليد هاشتاقات
    FilledButton.icon(
      icon: const Icon(Icons.tag),
      label: const Text("توليد هاشتاقات"),
      onPressed: isLoading ? null : _generateHashtags,
    ),
  ],
),
\\\

---

## 6️⃣ تحديثات GeminiService

### دالة جديدة - generateCustomContent()
\\\dart
/// Generate custom content with user prompt and optional image
Future<String> generateCustomContent(
  String userPrompt, 
  {Uint8List? imageBytes, String contentType = 'image/png'}
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
    final response = await _model!.generateContent([Content.text(userPrompt)]);
    return (response.text ?? '').trim();
  }
}
\\\

### دالة جديدة - generateAdvertisement()
\\\dart
/// Generate marketing advertisement based on image and prompt (Arabic)
Future<String> generateAdvertisement(
  Uint8List bytes, 
  String userPrompt,
  {String contentType = 'image/png'}
) async {
  await _ensureModel();
  
  final enhancedPrompt =
      'اكتب إعلانًا تسويقياً احترافياً وجذابًا بالعربية لهذا المنتج. طلب العميل: \\\n'
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

---

## 7️⃣ أمثلة الاستخدام

### مثال 1: بدون أوامر مخصصة
\\\dart
// المستخدم يختار صورة
// المستخدم يترك الحقل فارغاً
// يضغط "توليد وصف"
// النتيجة: وصف افتراضي احترافي
\\\

### مثال 2: مع أوامر مخصصة
\\\dart
// المستخدم يختار صورة العطر
// يكتب: "عطر فاخر موجه للنساء، ركز على الرقي"
// يضغط "توليد وصف"
// النتيجة: وصف يركز على الفخامة والرقي والجمهور المستهدف
\\\

### مثال 3: للإعلان التسويقي
\\\dart
// المستخدم يختار صورة المنتج
// يكتب: "استهدف النساء العاملات"
// يضغط "إعلان تسويقي"
// النتيجة: إعلان قوي يجذب النساء العاملات
\\\

---

## 🔍 نقاط مهمة في الكود

### 1. Safety (الأمان)
\\\dart
// تحقق من الصورة أولاً
if (_imageFile == null) {
  _showToast("لم يتم اختيار صورة");
  return;
}

// تنظيف المتحكم في dispose
_promptController.dispose();
\\\

### 2. Async/Await (البرمجة غير المتزامنة)
\\\dart
// استخدم await للعمليات الطويلة
final result = await gemini.generateCustomContent(...);

// استخدم mounted للتحقق من الـ widget
if (mounted) setState(() => productDescription = result);
\\\

### 3. Error Handling (معالجة الأخطاء)
\\\dart
try {
  // العملية
} catch (e) {
  _showSnack("خطأ: \", error: true);
} finally {
  setState(() => isLoading = false);
}
\\\

### 4. RTL Support (دعم اليمين لليسار)
\\\dart
TextField(
  textAlign: TextAlign.right,  // ✅ مهم للعربية
  fontFamily: 'IBMPlexSansArabic',  // ✅ خط عربي
)
\\\

---

## ✅ قائمة المراجعة الكاملة

- ✅ TextEditingController مهيأ في initState
- ✅ TextEditingController منظف في dispose
- ✅ حقل TextField موجود في الواجهة
- ✅ حقل TextField متصل بـ controller
- ✅ حقل TextField يدعم RTL والعربية
- ✅ دالة _generateDescription معدّلة
- ✅ دالة _generateAdvertisement مضافة
- ✅ زر الإعلان في الواجهة
- ✅ زر الإعلان متصل بـ الدالة
- ✅ GeminiService به دالتين جديدتين
- ✅ معالجة الأخطاء موجودة
- ✅ رسائل Toast واضحة
- ✅ كود نظيف وآمن

---

**آخر تحديث:** 11 نوفمبر 2025
**الإصدار:** 1.0
**الحالة:** ✅ جاهز للاستخدام
