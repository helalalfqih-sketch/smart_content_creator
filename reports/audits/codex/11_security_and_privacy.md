# الأمن والخصوصية

> لا توجد قيم سرية في التقرير؛ المواقع والأنواع فقط. القواعد المحلية لا تثبت أنها المنشورة.

## Critical

1. تصعيد role ذاتي: `firestore.rules:6-18` يسمح للمالك بكتابة المستند الذي تعتمد عليه `isAdmin`.
2. قراءة جميع users لأي authenticated: `firestore.rules:12-18`؛ مستندات قد تضم social tokens/settings.
3. Storage wildcard: `storage.rules:28-30` يسمح read/write لأي authenticated على أي path.
4. Credentials ثابتة في `functions/make_admin.js:8-16`, `functions/main.js:6`, `functions/catalog_cloud_code.js:11`, `instagram_service.dart:19-20`, `social_media_api_client.dart:7`, وlive test `manus_live_verification_test.dart:52-53`؛ القيم منقحة.
5. Endpoints حساسة بلا auth/role/signature/rate limit كافٍ: `functions/main.js:797-854,1571-1585,1980-2197,2610-2899`.

## High

- App Check debug دون build guard: `main.dart:88-98`.
- OAuth exchange client-side/query secret وstate متوقع/PKCE ناقص: `instagram_service.dart:206-417`, `tiktok_account_service.dart:269-288,523-526`.
- logging للheaders/bodies/full URLs: `enterprise_api_client.dart:38-61,120-122`.
- OTP بـMath.random وبلا rate limit/transaction: `functions/index.js:98-194`.
- catalogMediaList بلا ownership: `functions/main.js:1571-1585`.
- سياسة الخصوصية لا تطابق تعدد providers/تخزين الرموز: `web_landing/privacy.html:125-155`, `privacy_policy_screen.dart:48-56`.

Android يسمح cleartext، deep links واسعة، وrelease قد يعود إلى debug signing. فحص التقارير النهائي يجمع patterns + أسماء حقول + سياق؛ Regex وحده لا يثبت الخلو.
