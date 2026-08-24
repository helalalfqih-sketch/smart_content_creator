# الاعتماديات والمنصات

## Dependencies

- 62 dependency مباشرة.
- 16 بلا import ساكن: `animate_do`, `chewie`, `connectivity_plus`, `file_selector`, `fl_chart`, `flutter_linkify`, `flutter_staggered_grid_view`, `google_generative_ai`, `in_app_purchase`, `lucide_icons`, `mime`, `permission_handler`, `process_run`, `video_player_win`, `webview_flutter`, `webview_flutter_android`. التصنيف `POSSIBLY_UNUSED` فقط.
- pubspec يسمح Dart>=3.3/Flutter>=3.22 (`pubspec.yaml:6-8`) بينما lock يتطلب Dart>=3.11/Flutter>=3.41 (`pubspec.lock:1944-1946`).

## المنصات

- Android: minSdk 24؛ compile/target ديناميكيان. cleartext enabled، debug-sign fallback، minify/shrink off، release lint non-blocking (`build.gradle.kts:61-118`).
- iOS: Info.plist يفتقد camera/photo descriptions رغم مسارات camera/gallery؛ لا URL types/Associated Domains واضحة. `NEEDS_RUNTIME_TEST`.
- iOS/macOS/Linux ما زالت identifiers `com.example`; Android `com.smartcontentcreator.app`.
- macOS DebugProfile يفتقد network.client بينما Release يملكه.
- Web branding افتراضي في manifest/index.
- Shorebird config موجود لكن CI لا ينفذ shorebird release/patch.
- workflow يبني وينشر بلا analyze/test/security gate: `.github/workflows/build_release.yml:43-96`.
