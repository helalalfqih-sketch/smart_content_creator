# الاختبارات والتحقق

- 19 ملف اختبار (15 test + 4 integration)، 100 تصريح test/testWidgets؛ loop قد يرفع الحالات إلى 104.
- Golden=0؛ direct-import reach = 19/229 ملف إنتاج = 8.3%، وليس code coverage.

| الفحص | النتيجة | الحالة |
|---|---|---|
| dart format tracked | command line طويل؛ دفعات بلا خرج موثوق | BLOCKED_BY_ENVIRONMENT |
| `dart analyze` | علق 10 دقائق بلا خرج؛ أوقفت جلسة الأمر فقط | BLOCKED_BY_ENVIRONMENT |
| result unit test | علق بلا خرج؛ أوقفت جلسة الأمر فقط | BLOCKED_BY_ENVIRONMENT |
| build | لم يُشغّل | NOT_RUN |

لا يوجد `VERIFIED_WORKING` جديد.

## اختبارات حية مستبعدة

- `manus_live_verification_test.dart:47-132`: login و20 POST متزامنًا وكتابات؛ credentials في 52-53.
- `wave1a_live_verification_test.dart:12-144`: Firebase live.
- `live_dual_read_runner_test.dart:18-72`: remote GET/POST.
- `integration_test/app_test.dart`: main الحقيقي/Firebase.

## جودة

- `catalog_xlsx_import_service_test.dart:9-15` و`media_audit.dart:10-15` false-green عند غياب الملف.
- `widget_test.dart:1-7` placeholder 1+1.
- `verify_llava.dart:4-14` executable POST محلي بلا assertions.
- AI integration constants لا تثبت end-to-end.
