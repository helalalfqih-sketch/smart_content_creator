# تدفقات المستخدم

كل التدفقات ساكنة ما لم يذكر خلاف ذلك.

- **أول تشغيل:** main → Supabase/storage/Firebase → InitialBinding → AuthController → Splash → home/login. `isLoggedIn` لا يميز anonymous (`auth_controller.dart:55-56,365-402`; `splash_screen.dart:68-73`)؛ `PARTIALLY_VERIFIED`.
- **Login/Logout:** input → validation `auth_controller.dart:560-568` → AuthService → profile/permissions → navigation. runtime Firebase غير مختبر.
- **Signup:** الاسم يمرر ثم يُهمل `auth_controller.dart:1329-1339` (`BROKEN`)؛ redirect `/home` ثم `/main` مكرر `603-609,680-712`.
- **Password reset:** reset link + deep link `auth_controller.dart:220-343`. OTP legacy يستدعي stub false `1364-1368` ولا caller له.
- **Chat:** UI → ChatState/ChatSmartAgent → TaskDistributor/Router/provider → ChatRepository/SQLite → UI. attachments في `chat_media_mixin.dart:29-175`. Workers بلا dispose `ai_chat_screen.dart:93-150`.
- **AI/media:** agent action → provider/gateway → parse → gallery/bubble → save/share. يوجد 28 `UnimplementedError`؛ routing يحتاج runtime matrix.
- **Catalog:** CatalogController → Back4AppRepository/SQLite → list/form/import. bulk delete لا ينتظر نتائج local/remote ذريًا `catalog_controller.dart:153-212`.
- **Search/filter/sort:** `filteredProducts` `773-843` يعيد الحساب ويستخدم DateTime.now داخل comparator.
- **WhatsApp/TikTok:** TikTok يعيد mock عند غياب token أو exception `tiktok_service.dart:321-330,448-450` دون وسم واضح.
- **Subscription:** SubscriptionService hard-coded unavailable وbuy/restore delays `subscription_service.dart:12-37`; fallback WhatsApp `subscription_screen.dart:486-505`.
- **Shorebird:** config موجود، لكن CI لا ينفذ release/patch؛ `NEEDS_RUNTIME_TEST`.
