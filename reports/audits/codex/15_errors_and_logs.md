# الأخطاء والسجلات

## build_error.txt

- غير متعقب، 458,616 بايت، UTF-16، 1,934 سطرًا، بتاريخ 2026-08-20.
- root cause تاريخي: kernel/native asset hook incompatible (`expected 127, found 130`) في 1089-1114.
- فشل كتابة AOT لثلاث معماريات في 1169-1177.
- Secondary: dart_build 1180، compileFlutterBuildRelease 1444، Gradle exit 1 في 1883-1891.
- APK أحدث بتاريخ 2026-08-24؛ لم يُعد إنتاج الخطأ. `HISTORICAL BROKEN / PARTIALLY_VERIFIED`.

`app_check_debug.txt` صفر بايت؛ لا دليل. analyzer/test علقا بلا output. فحص command line للعمليات رُفض بالصلاحيات؛ لم تُوقف عمليات Dart/Java جماعيًا.
