# التخزين والنماذج

## التخزين

- `lib/services/db_service.dart`: SQLite/migrations/sync/cache/settings.
- `lib/database/database_helper.dart`: SQLite ثانٍ/قديم؛ خطر مصدرَي حقيقة.
- `app_storage_service.dart:14-44`: GetStorage + migration من SharedPreferences.
- `secure_storage_service.dart`: secure storage لحقول مختارة.
- ملفات temp/documents في خدمات media/image.

## مخاطر مثبتة

- SQL `IN (...)` بضم identifiers: `back4app_catalog_repository.dart:147-160`.
- `REPLACE` قد يعيد إنشاء الصف: `db_service.dart:467-490`.
- لا دليل `PRAGMA foreign_keys=ON`: `db_service.dart:98,162-164`.
- `user_id IS NULL` يظهر لكل مستخدم محلي: `db_service.dart:536-552`.
- مفاتيح API plaintext: `db_service.dart:130-137`, `database_helper.dart:50-57`.
- migration قد ينقل secrets إلى GetStorage: `app_storage_service.dart:25-44,102-106`.
- outbox بلا backoff/dead-letter: `repository.dart:565-620`.

فُهرس نحو 22 model file. CatalogProductModel محور id/price/currency/media/external IDs. تحويل price/quantity/DateTime يختلف بين Excel/SQLite/remote ويحتاج contract fixtures.

Cloud integrity: catalog update غير CAS ذري `functions/main.js:1392-1460`؛ media/uniqueness check-then-write `330-349,1613-1654`؛ `functions/index.js:49` يستخدم `sizeBytes` قبل تعريفه (`BROKEN`). التوافق الحي `PARTIALLY_VERIFIED`.
