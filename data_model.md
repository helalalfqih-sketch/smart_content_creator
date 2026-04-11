# توثيق نموذج البيانات وقاعدة البيانات (Data Model & Schema)

هذا المستند يشرح هيكلية البيانات في المشروع، بما في ذلك الربط بين قاعدة البيانات المحلية (SQLite) والسحابية (Firestore).

## 1. مخطط قاعدة البيانات (ER Diagram)

المخطط التالي يوضح الجداول الرئيسية والعلاقات بينها:

```mermaid
erDiagram
    USERS ||--o{ CHAT_SESSIONS : owns
    USERS ||--o{ CHAT_HISTORY : sends
    USERS ||--o{ USER_PERMISSIONS : has
    UI_CONTROLS ||--o{ USER_PERMISSIONS : controlled_by
    CHAT_SESSIONS ||--o{ CHAT_HISTORY : contains
    PRODUCTS ||--o{ PRODUCT_MEDIA : has
    PRODUCTS ||--o{ CHAT_HISTORY : referenced_in

    USERS {
        int id PK
        string email UK
        string username
        string password_hash
        string role
        string bio
        datetime created_at
    }

    CHAT_SESSIONS {
        int id PK
        string title
        string user_id FK
        datetime created_at
        datetime last_message_at
    }

    CHAT_HISTORY {
        int id PK
        int session_id FK
        string user_id FK
        string user_message
        string ai_response
        string message_type
        string media_path
        string meta_data
        datetime created_at
    }

    PRODUCTS {
        int id PK
        string name
        string description
        string image_path
        string category
        datetime created_at
    }

    API_KEYS {
        int id PK
        string service_name UK
        string api_key
        int enabled
        datetime created_at
    }
```

---

## 2. تفاصيل الجداول المحلية (SQLite)

يعتمد التطبيق على SQLite لإدارة البيانات التي تتطلب وصولاً سريعاً أو تعمل في وضع عدم الاتصال:

| الجدول | الوصف | الحقول الرئيسية |
| :--- | :--- | :--- |
| `users` | بيانات المستخدمين المحليين | `id`, `email`, `role`, `password_hash` |
| `chat_sessions` | جلسات الدردشة | `id`, `title`, `user_id` |
| `chat_history` | الرسائل داخل الجلسات | `session_id`, `user_message`, `ai_response`, `media_path` |
| `products` | الكتالوج الخاص بالمنتجات | `name`, `description`, `image_path` |
| `api_keys` | مفاتيح الخدمات (Gemini, TikTok, الخ) | `service_name`, `api_key`, `enabled` |
| `response_cache` | التخزين المؤقت للذكاء الاصطناعي | `input_hash`, `response_data`, `type` |

---

## 3. نماذج البيانات البرمجية (Data Models)

يتم تمثيل الجداول في الكود عبر كلاسات Dart (Entities) لسهولة التعامل معها:

### ChatMessage
يمثل رسالة واحدة في الدردشة، سواء كانت نصية، صورة، أو فيديو.
- **الحقول**: `id`, `role`, `content`, `type`, `mediaPath`, `state`.

### TikTokVideo
يمثل بيانات الفيديو المجلوب من TikTok للتحليل.
- **الحقول**: `id`, `videoUrl`, `title`, `author`, `thumbnailUrl`, `views`.

### Product
يمثل المنتج الذي يتم تحليله وتوليد محتوى له.
- **الحقول**: `id`, `name`, `description`, `imagePath`.

---

## 4. التكامل مع Firebase (Hybrid Model)

يتم مزامنة بعض هذه البيانات مع **Firestore** لضمان توفرها على أجهزة متعددة:

1.  **المستخدمين**: يتم ربط `user_id` المحلي بـ `Firebase Auth UID`.
2.  **الدردشات**: يتم نسخ الرسائل من `chat_history` إلى مجموعة `messages` في Firestore عبر `FirebaseChatService`.
3.  **الملفات**: تُرفع الصور والفيديوهات إلى `Firebase Storage` ويُخزن الرابط (URL) في قاعدة البيانات.
