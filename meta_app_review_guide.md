# دليل إرسال تطبيق Smart Content Creator لمراجعة Meta (Meta App Review Guide)

عند تقديم طلب مراجعة التطبيق في لوحة مطوري Meta للحصول على الأذونات للإنتاج (Live Mode)، سيطلب منك المراجعون إجابات دقيقة لعدة أقسام. إليك الإجابات النموذجية باللغتين العربية والإنجليزية، والخطوات التفصيلية لإكمال التقديم بنجاح.

---

## 📄 سياسة الخصوصية (Privacy Policy)
*   **المتطلب:** رابط سياسة خصوصية صالح ويعمل.
*   **الحل:** قمنا بتجهيز سياسة خصوصية احترافية بالكامل متوافقة مع متطلبات Meta وجاهزة للنشر في ملف [terms.html](file:///d:/web/smart_content_creator_github/terms.html).
*   **الإجراء:** عند رفع التطبيق إلى الاستضافة الخاصة بك (Firebase Hosting مثلاً)، استخدم رابط هذه الصفحة كـ **Privacy Policy URL**.

---

## 📝 الأذونات وحالات الاستخدام (Permissions & Use Cases)

إليك النصوص الجاهزة لملء خانة **"كيف يستخدم تطبيقك هذا الإذن؟" (How is your app using this permission?)** لكل خدمة:

### 1. حالة استخدام كتالوج المنتجات (Catalog API - `catalog_management`)
*   **الوصف باللغة العربية:**
    > "يسمح تطبيقنا للتجار بإدارة منتجاتهم محلياً وسحابياً وتوليد مقاطع فيديو تسويقية لها باستخدام الذكاء الاصطناعي. نستخدم إذن `catalog_management` لتمكين التاجر من مزامنة وإرسال المنتجات المعتمدة مباشرة من التطبيق إلى كتالوج أعمال Meta الخاص به (Commerce Manager) بطلب مباشر وبلمسة واحدة، مما يوفر عليه الوقت ويمنع إدخال البيانات يدوياً."
*   **Description in English:**
    > "Our app allows merchants to manage their products and generate AI marketing videos. We use the `catalog_management` permission to enable merchants to sync and push approved products directly from the app dashboard into their Meta Commerce Catalog, saving time and automating product feeds."

---

### 2. حالة استخدام المراسلة عبر واتساب (WhatsApp Cloud API - `whatsapp_business_messaging`)
*   **الوصف باللغة العربية:**
    > "يستخدم التطبيق واجهة WhatsApp Cloud API لإرسال إشعارات المنتجات، والفيديوهات التسويقية التي يتم إنشاؤها بالذكاء الاصطناعي، وقوالب الرسائل المعتمدة إلى جهات اتصال العملاء الخاصة بالتاجر بناءً على طلبه لتمكينه من التسويق المباشر وتتبع الطلبات وسرعة التواصل."
*   **Description in English:**
    > "Our app uses the WhatsApp Cloud API to send product updates, AI-generated promotional videos, and pre-approved message templates directly to the merchant's customer list, facilitating automated marketing and order updates."

---

### 3. حالة استخدام نشر محتوى انستقرام (Instagram Graph API - `instagram_content_publish`)
*   **الوصف باللغة العربية:**
    > "يساعد التطبيق التجار والمبدعين في صناعة محتوى تسويقي احترافي للمنتجات. نستخدم إذن `instagram_content_publish` للسماح للمستخدم بنشر الصور ومقاطع الفيديو الترويجية (Reels) التي يولدها التطبيق بالذكاء الاصطناعي مباشرة على حساب الأعمال الخاص به على انستقرام دون الحاجة للخروج من التطبيق."
*   **Description in English:**
    > "Our application helps merchants design and generate marketing videos. We use the `instagram_content_publish` permission to allow users to directly publish these AI-generated promotional videos and posts (Reels) to their linked Instagram Business profile."

---

## 🎥 دليل تسجيل الفيديو التوضيحي (Screencast / Demo Video)
تطلب Meta تصوير مقطع فيديو قصير (أقل من 100 ميجابايت) يوضح آلية عمل الربط. إليك ما يجب عليك تصويره لضمان القبول:

1.  **تسجيل الدخول والتنقل:** افتح التطبيق، وسجل الدخول بحسابك.
2.  **الربط والمصادقة:** انتقل إلى شاشة "الإعدادات"، واضغط على زر "ربط Meta"، وأظهر نافذة تسجيل الدخول/OAuth الخاصة بفيسبوك/انستقرام.
3.  **تحديث الكتالوج (Catalog API):**
    *   اذهب لكتالوج المنتجات في التطبيق.
    *   أضف منتجاً جديداً أو عدله.
    *   اضغط على زر **"مزامنة مع Meta"**.
    *   افتح متصفح الويب واعرض لوحة التحكم في Meta Commerce Manager لتُظهر للمراجع أن المنتج ظهر هناك بنجاح.
4.  **إرسال رسالة واتساب:**
    *   اختر منتجاً أو فيديو تسويقياً مولداً.
    *   اضغط على "مشاركة عبر واتساب الأعمال".
    *   أظهر استلام الرسالة التجريبية على الهاتف الآخر.

---

## 🔐 تعليمات المراجع (Reviewer Testing Instructions)
في مربع نص "تعليمات المراجع"، اكتب لهم:
> "To test the integration, you can register a new account on our app sandbox. We have pre-configured a test Meta App Catalog ID and a WhatsApp Sandbox Phone Number in the settings. You can edit any product in the Catalog screen and click 'Sync to Meta' or click 'WhatsApp Share' to see the requests sent to the Graph API sandbox endpoints."
