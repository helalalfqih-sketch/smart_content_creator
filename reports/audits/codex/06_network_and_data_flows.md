# الشبكة وتدفقات البيانات

الحالة `STATICALLY_VALID` للسجل الساكن؛ لم تُرسل طلبات شبكة أو كتابة.

## الأنظمة

Firebase Auth/Firestore/Storage/App Check/Functions، Back4App، Supabase، مزودو AI، SerpApi/Jina/search، TikTok/Meta/Instagram/Facebook، Telegram/WhatsApp، YouTube.

| المصدر | Method/endpoint منقح | Auth | ملاحظة |
|---|---|---|---|
| `enterprise_api_client.dart:38-122` | dynamic HTTP | headers | يسجل URL/headers/body |
| `openai_service.dart:23-49` | POST provider | bearer | Dio مباشر؛ policy غير موحدة |
| `anthropic_service.dart:8-31` | POST provider | API key | Dio مباشر |
| `groq_service.dart:8-38` | POST provider | bearer | adapter مكرر |
| `deepseek_service.dart:8-38` | POST provider | bearer | adapter مكرر |
| `serpapi_master_service.dart:71-125` | GET search | query credential | DI fallback قد يفشل |
| `back4app_catalog_repository.dart:63-112` | paged catalog | Parse headers | 15s/page؛ تسلسلي |
| `functions/main.js:797-854` | AI/webhook | auth غير كافٍ | cost/mutation risk |
| `functions/main.js:1571-1585` | catalogMediaList | Master server | ownership مفقود |
| `functions/index.js:106-194` | OTP | ضعيف | no rate limit/transaction |

لا يوجد client مركزي مفروض على كل الخدمات؛ timeout/retry/backoff/cancellation/idempotency/rate limiting/offline mapping متفاوتة. المحادثات والوسائط وبيانات المستخدم قد تعبر إلى مزودين متعددين، والسجلات قد تحتوي PII أو credentials.

لم تنفذ GET في هذا التدقيق؛ runtime للشبكة `BLOCKED_BY_ENVIRONMENT` أو `NEEDS_RUNTIME_TEST`.
