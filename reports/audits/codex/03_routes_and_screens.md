# المسارات والشاشات

- 19 `GetPage` في `lib/main.dart:173-238`؛ `/home` و`/main` يعيدان MainWrapper نفسه.
- 21 شاشة أساسية مكتشفة؛ الوصول الساكن 18/21 = 85.7%.

| Route | Screen | Evidence | Reachability |
|---|---|---|---|
| `/login` | LoginScreen | `main.dart:174-176` | Splash |
| `/signup` | SignupScreen | `main.dart:177-179` | Login:274 |
| `/password-reset-otp` | PasswordResetOtpScreen | `main.dart:180-185` | UNREACHABLE |
| `/account-confirmation` | AccountConfirmationScreen | `main.dart:186-188` | UNREACHABLE |
| `/splash` | SplashScreen | `main.dart:189-191` | named بلا caller |
| `/chat` | AiChatScreen | `main.dart:194-196` | داخل MainWrapper؛ named بلا caller |
| `/home`, `/main` | MainWrapper | `main.dart:197-202` | Splash/Auth |
| `/settings` | GeneralSettingsScreen | `main.dart:203-205` | Chat/settings |
| `/api-settings` | SettingsScreen | `main.dart:206-208` | GeneralSettings |
| `/creator-profile` | CreatorProfileScreen | `main.dart:209-211` | drawer |
| `/admin` | AdminDashboardScreen | `main.dart:212-214` | drawer/profile؛ guard داخل الشاشة |
| `/admin/users` | UsersListScreen | `main.dart:215-217` | UNREACHABLE |
| `/edit-profile` | EditProfileScreen | `main.dart:218-220` | direct constructor |
| `/privacy`, `/terms` | policy screens | `main.dart:221-226` | GeneralSettings |
| `/subscription` | SubscriptionScreen | `main.dart:227-229` | direct constructor |
| `/product-photography` | ProductPhotographyScreen | `main.dart:230-233` | direct constructor |
| `/catalog` | ProductCatalogScreen | `main.dart:234-237` | drawer |

لا GetMiddleware على المسارات المعلّمة «محمية» (`main.dart:193-237`). الحماية الحقيقية يجب أن تكون server-side.

الجرد التفصيلي في `04_ui_controls_inventory.csv`: 279 عنصرًا heuristic. مسح callbacks وجد نحو 376 binding. لا `Semantics(` أو `semanticLabel:` في نطاق UI؛ الوصولية وRTL والقص والتباين واللوحة/الدوران `NEEDS_RUNTIME_TEST`.
