# تدقيق الاتصالات والشبكة — Network & API Integration
## مشروع Smart Content Creator

---

## 1. خريطة الاتصالات والـ Endpoints الخارجية

يستخدم التطبيق حزم `http` و `dio` ومكتبات SDK رسمية للاتصال بالخدمات السحابية ومزودي الـ AI:

| # | الخدمة الخارجية | وسيلة الاتصال والبروتوكول | الغرض ونوع البيانات المنقولة | معالجة الأخطاء والـ Fallback |
|---|---|---|---|---|
| 1 | **Back4App Parse Cloud Code** | HTTP REST / JSON via `http` | بوابة الذكاء الاصطناعي، استعلام وتخزين المنتجات والوسائط | يدعم التدوير التلقائي بين 18 مفتاح ومحاولة إعادة الاتصال |
| 2 | **Firebase Cloud Firestore** | gRPC / WebSocket عبر SDK | حفظ ومزامنة المستخدمين، السجلات، الإعدادات العالمية | Offline Persistence مفعل تلقائياً |
| 3 | **Firebase Storage** | HTTPS عبر Firebase SDK | رفع واسترجاع وسائط المحادثات وملف الكتالوج | ⚠️ 127 رابط فيديو قديم يرجع HTTP 412 (Precondition Failed) |
| 4 | **Supabase Auth & Storage** | REST / PostgREST عبر Supabase SDK | مصادقة الحسابات وتخزين صور الكتالوج | 117 رابط صورة يعمل بنجاح |
| 5 | **Google Gemini API** | REST API / SDK | محادثات الذكاء الاصطناعي، تحليل الصور والفيديوهات | توجيه تلقائي عبر AIBackendRouter |
| 6 | **SerpApi Engine** | HTTPS GET REST API | محركات بحث Google Lens, Trends, Shopping | معالجة زمن الاستجابة ورمي Exception مهيأ |
| 7 | **TikTok / Meta APIs** | OAuth 2.0 / HTTPS REST | نشر المحتوى ومزامنة صفحات ومتاجر التواصل | معالجة انتهاء صلاحية الـ Tokens |

---

## 2. مصفوفة التحقق من الروابط والوسائط (Media Verification Matrix)

بناءً على فحص الـ HTTP Probes المسجل في `catalog_media_http_results.csv`:

```
┌─────────────────────────────────────────────────────────────┐
│                    MEDIA STATUS SUMMARY                     │
├────────────────────────────┬─────────┬──────────────────────┤
│ Provider / Storage         │ Count   │ Status Code          │
├────────────────────────────┼─────────┼──────────────────────┤
│ Supabase Images (Catalog)  │ 117     │ 200 OK (Working)     │
│ Back4App Video Files       │ 4       │ 200 OK (Working)     │
│ Firebase Storage Videos    │ 127     │ 412 Precondition Fail│
└────────────────────────────┴─────────┴──────────────────────┘
```

> [!WARNING]
> **مشكلة روابط Firebase 412:**
> تعود لروابط مخزنة قديماً بتنسيق Firebase Storage URLs قديم أو تتطلب توكنات انتفاع انتهت صلاحيتها أو قيود في الـ Bucket rules القديم. تم تطوير أداة إصلاح الوسائط في commit `f40bd21` لترحيل هذه الروابط تدريجياً لـ Parse Files.

---

## 3. تدقيق معالجة أخطاء الشبكة (Error Handling & Timeout Policies)

1. **المهلات الزمنية (Timeouts):**
   - تم ضبط مهلات `Duration(seconds: 15..30)` في معظم استدعاءات `Back4AppGatewayService` و `GeminiService`.
2. **الاستجابة لفقدان الإنترنت:**
   - يمتلك التطبيق فحص اتصال عبر `connectivity_plus` ويتحول وضع Firestore و SQLite للعمل غير المتصل دون انهيار الواجهة.
3. **حماية التكرار وإعادة المحاولة (Retry Mechanism):**
   - تم بناء منطق Retry في استدعاءات الذكاء الاصطناعي لتجربة نماذج أو مفاتيح بديلة قبل إشعار المستخدم بالخطأ.
