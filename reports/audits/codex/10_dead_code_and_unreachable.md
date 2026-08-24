# الكود الميت وغير القابل للوصول

| العنصر | الدليل | التصنيف |
|---|---|---|
| PasswordResetOtpScreen | route بلا caller؛ stub false `auth_controller.dart:1364-1368` | UNREACHABLE/BROKEN |
| AccountConfirmationScreen | route بلا caller؛ stub `1370-1377` | UNREACHABLE |
| UsersListScreen | route بلا in-app caller | UNREACHABLE |
| NavigationController bar state | لا consumer يرسم bar | DEAD_CODE محتمل |
| About tile | `creator_profile_screen.dart:215-225` onTap فارغ | BROKEN |
| `ai_chat_screen.dart.tmp` | tracked backup بلا import | DEAD_CODE |
| `lib/screens/Untitled-1.txt` | HTML بلا reference | DEAD_CODE |
| `assets/images/background.jpg` | صفر بايت، معلن بلا use | BROKEN/DEAD محتمل |
| AgentRouter/flags | لا references خارج الملفات | DEAD_CODE بثقة عالية |
| TikTok mock fallback | reachable عند exception | BROKEN، ليس dead |
| 28 UnimplementedError | providers قابلة للإنشاء | NEEDS_RUNTIME_TEST |

الاعتماديات غير المستخدمة تحتاج analyzer. 16 dependency بلا import ساكن هي `POSSIBLY_UNUSED` فقط بسبب platform registration/dynamic usage.
