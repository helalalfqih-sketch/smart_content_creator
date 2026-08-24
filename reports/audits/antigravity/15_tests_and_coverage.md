# الاختبارات والتغطية — Tests & Coverage

---

## 1. فهرس الاختبارات المكتشفة

### Unit / Widget Tests (test/)

| # | الملف | الحجم | النوع | يتصل بخدمة حية؟ | الحالة |
|---|---|---|---|---|---|
| 1 | `widget_test.dart` | 200 B | Widget | لا | LIKELY_BROKEN (شبه فارغ) |
| 2 | `ai_backend_router_test.dart` | 9,033 B | Unit | نعم (Back4App) | BLOCKED_BY_ENVIRONMENT |
| 3 | `catalog_dual_read_verification_test.dart` | 2,869 B | Unit | نعم (Back4App + SQLite) | BLOCKED_BY_ENVIRONMENT |
| 4 | `catalog_excel_parser_test.dart` | 3,273 B | Unit | لا (محلي) | REQUIRES_APPROVAL |
| 5 | `catalog_xlsx_import_service_test.dart` | 1,224 B | Unit | لا (محلي) | REQUIRES_APPROVAL |
| 6 | `chinese_platform_query_test.dart` | 2,728 B | Unit | نعم (AI) | BLOCKED_BY_ENVIRONMENT |
| 7 | `controlled_dual_write_test.dart` | 16,193 B | Integration-like | نعم (Back4App + Firebase) | BLOCKED_BY_ENVIRONMENT |
| 8 | `deterministic_router_test.dart` | 4,874 B | Unit | نعم (AI routers) | BLOCKED_BY_ENVIRONMENT |
| 9 | `firebase_prompt_wave1a_test.dart` | 6,085 B | Integration | نعم (Firebase AI) | BLOCKED_BY_ENVIRONMENT |
| 10 | `live_dual_read_runner_test.dart` | 4,283 B | Live | نعم (Back4App) | BLOCKED_BY_ENVIRONMENT |
| 11 | `manus_ai_provider_test.dart` | 8,579 B | Integration | نعم (Back4App AI) | BLOCKED_BY_ENVIRONMENT |
| 12 | `media_audit.dart` | 1,983 B | Audit script | نعم (HTTP) | BLOCKED_BY_ENVIRONMENT |
| 13 | `verify_llava.dart` | 581 B | Verification | نعم (AI) | BLOCKED_BY_ENVIRONMENT |
| 14 | `whatsapp_sync_contract_test.dart` | 7,379 B | Contract | نعم (WhatsApp API) | BLOCKED_BY_ENVIRONMENT |

### Integration Tests (integration_test/)

| # | الملف | الحجم | النوع | يتصل بخدمة حية؟ | الحالة |
|---|---|---|---|---|---|
| 15 | `app_test.dart` | 2,047 B | Integration | نعم (كامل التطبيق) | BLOCKED_BY_ENVIRONMENT |
| 16 | `ai_orchestrator_integration_test.dart` | 1,162 B | Integration | نعم (AI) | BLOCKED_BY_ENVIRONMENT |
| 17 | `manus_live_verification_test.dart` | 6,118 B | Live verification | نعم (Back4App) | BLOCKED_BY_ENVIRONMENT |
| 18 | `wave1a_live_verification_test.dart` | 6,438 B | Live verification | نعم (Firebase AI) | BLOCKED_BY_ENVIRONMENT |

---

## 2. تحليل التغطية

### 2.1 الميزات المغطاة باختبارات

| الميزة | اختبار موجود؟ | نوع | كافٍ؟ |
|---|---|---|---|
| AI Backend Router | ✅ | Unit | جزئي |
| Catalog Dual Read | ✅ | Verification | جزئي |
| Catalog Excel Import | ✅ | Unit | جزئي |
| Controlled Dual Write | ✅ | Integration-like | شامل نسبياً |
| AI Orchestrator | ✅ | Integration | أساسي |
| WhatsApp Sync | ✅ | Contract | جزئي |

### 2.2 الميزات بدون اختبارات

| الميزة | الأهمية | اختبار مطلوب؟ |
|---|---|---|
| **تسجيل الدخول/الخروج** | حرجة | ✅ ضروري |
| **إنشاء/تعديل/حذف منتج** | حرجة | ✅ ضروري |
| **UI Widgets** | عالية | ✅ ضروري |
| **Navigation / Routes** | عالية | ✅ ضروري |
| **Admin Dashboard** | عالية | ✅ ضروري |
| **Settings Controller** | متوسطة | ✅ مطلوب |
| **Media Upload/Download** | عالية | ✅ ضروري |
| **Export Excel** | متوسطة | ✅ مطلوب |
| **Search/Filter/Sort** | متوسطة | ✅ مطلوب |
| **Product Photography AI** | متوسطة | مرغوب |
| **Subscription/Payment** | عالية | ✅ ضروري |
| **TikTok Integration** | متوسطة | مرغوب |
| **Error Handling** | حرجة | ✅ ضروري |

### 2.3 نسبة التغطية المقدرة

| البند | المغطى | الإجمالي | النسبة |
|---|---|---|---|
| ملفات الاختبار | 18 | 18 (مكتشفة) | 100% مفهرسة |
| اختبارات قابلة للتشغيل محلياً | 2 | 18 | ~11% |
| ميزات مغطاة باختبارات | 6 | 20+ | ~30% |
| Controllers مختبرة | 1 (Catalog جزئياً) | 15 | ~7% |
| Screens مختبرة (Widget tests) | 0 | 20 | 0% |

---

## 3. ملاحظات على جودة الاختبارات

1. **widget_test.dart** (200 bytes) — شبه فارغ، لا يختبر شيئاً ذا قيمة.
2. **معظم الاختبارات تتصل بخدمات حية** — لا يمكن تشغيلها في بيئة CI/CD بدون أسرار.
3. **لا توجد mocks أو fakes** — الاختبارات تعتمد على البنية الفعلية.
4. **لا يوجد golden tests** — لا اختبارات بصرية للواجهات.
5. **لا يوجد اختبارات أداء** — لا قياس لسرعة التحميل أو استهلاك الذاكرة.

---

## 4. التوصيات

1. إنشاء اختبارات Unit معزولة باستخدام mocks لكل Controller وService
2. إنشاء Widget tests لكل شاشة رئيسية
3. فصل اختبارات الخدمات الحية في مجموعة منفصلة (tagged tests)
4. إضافة integration_test حقيقي يغطي Login → Home → Catalog flow
5. إضافة golden tests للتصميم
