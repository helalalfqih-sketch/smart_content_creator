# التخزين ونماذج البيانات — Data Storage & Models

---

## 1. نماذج البيانات (Models)

### 1.1 CatalogProduct [models/catalog_product_model.dart] — 31,976 bytes

النموذج الأساسي لمنتجات الكتالوج. يحتوي حقول Meta Catalog الكاملة:

| الحقل | النوع | الغرض | ملاحظة |
|---|---|---|---|
| `id` | String? | معرف فريد | يأتي من Back4App objectId |
| `externalId` | String? | معرف خارجي (Meta/Facebook) | |
| `title` | String | اسم المنتج | مطلوب |
| `description` | String | وصف المنتج | |
| `link` | String | رابط المنتج | |
| `imageLink` | String | رابط الصورة | |
| `additionalImageLinks` | List<String> | صور إضافية | |
| `videoUrl` | String? | رابط الفيديو | 127 رابط Firebase معطل |
| `price` | double | السعر | |
| `salePrice` | double? | سعر التخفيض | |
| `currency` | String | العملة | |
| `availability` | String | حالة التوفر | |
| `quantity` | int | الكمية | |
| `brand` | String | العلامة التجارية | |
| `category` | String | التصنيف | |
| `condition` | String | الحالة (new/used/refurbished) | |
| `creatorUid` | String | معرف المنشئ | |
| `createdAt` | DateTime? | تاريخ الإنشاء | |
| `updatedAt` | DateTime? | تاريخ التحديث | |

**Serialization:**
- `toJson()` — تحويل لـ Map (Back4App)
- `fromJson()` — إنشاء من Map
- `toSqliteMap()` — تحويل لقاعدة SQLite المحلية
- `fromSqliteMap()` — إنشاء من SQLite
- `copyWith()` — نسخ مع تعديل

**مشاكل مكتشفة:**
- النموذج يحتوي **54 حقلاً+ تقريباً** — ضخم جداً لنموذج واحد
- `toJson` و `fromJson` يتعاملان مع عدة مصادر (Back4App, Firestore, SQLite, Excel) — يزيد التعقيد

### 1.2 CatalogMediaModel [models/catalog_media_model.dart] — 4,595 bytes

نموذج وسائط الكتالوج (صور/فيديوهات):

| الحقل | النوع |
|---|---|
| `objectId` | String? |
| `productId` | String |
| `mediaType` | String (image/video) |
| `url` | String |
| `fileName` | String |

### 1.3 UserModel [models/user_model.dart] — 2,906 bytes

| الحقل | النوع |
|---|---|
| `uid` | String |
| `email` | String |
| `displayName` | String |
| `role` | String (user/admin) |
| `createdAt` | DateTime |

### 1.4 نماذج أخرى

| النموذج | الملف | الحجم | الغرض |
|---|---|---|---|
| ApiKeyModel | `api_key_model.dart` | 1,950 B | تخزين مفاتيح API |
| BrandIdentityModel | `brand_identity_model.dart` | 2,388 B | هوية العلامة التجارية |
| ContentModel | `content_model.dart` | 2,355 B | محتوى AI |
| LogModel | `log_model.dart` | 1,549 B | سجل النشاط |
| MediaModel | `media_model.dart` | 1,495 B | وسائط عامة |
| ProductMemoryModel | `product_memory_model.dart` | 3,212 B | ذاكرة المنتجات |
| ProductPhotoModels | `product_photo_models.dart` | 8,845 B | نماذج التصوير |
| SettingModel | `setting_model.dart` | 1,539 B | إعدادات |
| UserActivity | `user_activity.dart` | 1,223 B | نشاط المستخدم |
| VideoComposition | `video_composition.dart` | 3,064 B | تكوين الفيديو |
| WhatsappSyncModels | `whatsapp_sync_models.dart` | 8,091 B | مزامنة واتساب |
| CatalogCategoryModel | `catalog_category_model.dart` | 1,976 B | تصنيفات |

---

## 2. قواعد البيانات

### 2.1 SQLite [services/db_service.dart] — 28,165 bytes

**جداول معروفة:**
- `catalog_products` — كتالوج المنتجات المحلي
- `chats` — سجل المحادثات
- `messages` — الرسائل
- `settings` — الإعدادات المحلية

**الحالة:** STATICALLY_VALID — لم يتم فحص مخطط قاعدة البيانات فعلياً (NEEDS_RUNTIME_TEST)

### 2.2 Cloud Firestore

**المجموعات المعروفة (من firestore.rules):**
- `users/{userId}` + sub-collections
- `subscriptions/{userId}`
- `app_settings/{id}`
- `global_config/{id}`
- `ui_controls/{id}`
- `user_permissions/{id}`
- `user_activity_logs/{id}`
- `catalog_products/{productId}`

### 2.3 Back4App (Parse Server)

**Classes المعروفة (من back4app_catalog_repository.dart):**
- `CatalogProduct` — المنتجات
- `CatalogMedia` — الوسائط

### 2.4 Supabase

**الاستخدام:** مصادقة + تخزين صور الكتالوج في Supabase Storage
**الجداول:** يحتاج فحص أعمق لتحديد الجداول المستخدمة

---

## 3. مشاكل البيانات المكتشفة

### 3.1 ازدواجية التخزين (Dual Storage)
المنتجات تُخزن في **3 أماكن**:
1. SQLite (محلي)
2. Back4App (سحابي — المصدر الرئيسي)
3. Firestore (تاريخي — `catalog_products` collection)

**الخطر:** عدم تطابق البيانات بين المصادر الثلاثة.

### 3.2 وسائط على 3 مخازن مختلفة
- **الصور:** Supabase Storage (117 صورة شغالة ✅)
- **الفيديوهات القديمة:** Firebase Storage (127 رابط معطل ❌ HTTP 412)
- **الفيديوهات الجديدة:** Back4App Parse Files (4 فيديوهات شغالة ✅)

### 3.3 تكرار المنتجات
من تقرير DRY RUN السابق:
- `export_products=1743`
- `duplicate_composite_groups=371`
- `duplicate_extra_copies=1357`

**التأثير:** 1357 نسخة مكررة في الكتالوج.

---

## 4. Firestore Indexes [firestore.indexes.json]

```json
{
  "indexes": [
    {
      "collectionGroup": "catalog_products",
      "fields": [
        {"fieldPath": "creatorUid", "order": "ASCENDING"},
        {"fieldPath": "updatedAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

**ملاحظة:** Index واحد فقط. قد يحتاج indexes إضافية للبحث والفلترة.
