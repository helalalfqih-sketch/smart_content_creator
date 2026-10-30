# Shorebird recovery — 2026-10-30

## Confirmed source
- Repository: helalalfqih-sketch/smart_content_creator, source commit 957bc43a01209ec1069db7f446fd9dd4ab0584cd.
- pubspec.yaml: 1.3.0+6.
- shorebird.yaml app_id: 50f79796-407c-4909-a7c2-8ed8d05d25b3; auto_update:false is commented.
- Android applicationId: com.smartcontentcreator.app.
- Authenticated Shorebird console: release 783074 (1.3.0+6), Flutter 3.44.6, created August 21 2026, stable patch #8.
- Console aarch64 release artifact hash starts a18734d6.
- Matching version and app ID do not establish that the current source commit exactly matches the original release or patch #8.

## APK investigation
GitHub v1.3.0 ARM64 APK:
- Published August 18 2026, before the Shorebird release.
- SHA256 806329e11d00931db1c28dcb0700843f80e9bcc9ae4e6336b6813451cf9c2df9 matches GitHub asset digest.
- Android build-tools 36.0.0 `aapt` reports package `com.example.smart_content_creator`,
  versionName `1.3.0`, versionCode `2006`. This differs from the current package
  `com.smartcontentcreator.app`; Android treats them as different apps.
- Independent `apksigner verify --verbose --print-certs` (build-tools 36.0.0)
  verified its v2 signature and exactly one signer. Its certificate SHA-256 is
  `421cd80d80141ef72cc26235e415277e1af862ffe369234f7d04538f74ba2636`,
  matching the recovered keystore. This certificate match does not fix the
  application-ID mismatch.
- libapp.so SHA256 723696a47a4294f154eea373ad412bb168c0a648abc443542b61a8cdf1168ae6 does not match the console release artifact prefix.
- libflutter.so has none of the inspected byte strings: shorebird, libshorebird, patch_check, api.shorebird.dev.
- It includes shorebird.yaml, but that alone does not establish an updater-enabled engine.
Do not distribute this APK as the verified OTA baseline. GitHub v2.1.0 assets are also dated before the console release; they have not been inspected.

## Original Shorebird bundle signing verified

Candidate run 41108099136 retrieved original AAB artifact 3463024 for release
783074 through authenticated GET requests, without changing any Shorebird key,
release or patch. Its SHA-256 was
`e22614462f459d299b574fa6db44ce846de41c009eb8abce97910359abd3d897`,
matching the API digest and byte size. Bundletool and JAR signature verification
confirmed `com.smartcontentcreator.app`, version `1.3.0+6`, with the same recovered
certificate above. The release Flutter revision was
`e34c42f91dd1fd26ef4700510245620e496c07bb`.
This establishes bundle signing continuity, not installed APK/Play App Signing
or OTA behavior. The run later failed Java compilation because `--no-pub` kept
integration_test in generated release registration. The candidate workflow now
uses Flutter's pub-enabled release path to regenerate the correct registrant.

Evidence: https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41108099136

## Existing work to preserve
Guest-mode PocketBase integration and server scripts are on
helalalfqih-sketch/- branch codex/scc-vps-production-foundation-20261029
(commit ced4e63b20d81c985458661517dffd102127c9a1).
That repo uses a different Android package (com.example.smart_content_creator).
Do not apply it blindly as a patch to this existing release.
No guest-mode migration has been performed here, and the live guest backend is not verified.

## Next build
The prerequisites workflow checks only whether the existing repository secrets
SHOREBIRD_TOKEN, KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS
are available to a GitHub runner. It never prints values, uploads a keystore,
or publishes a release. A separate job uses SHOREBIRD_TOKEN for one authenticated
GET of this app's metadata from Shorebird; it verifies the app and organization
IDs without printing response data or testing release/patch write permissions.
All five secrets were available on prerequisite run 41099341611, attempt 3.
The recovered keystore, alias, store password and private-key password passed
actual temporary-JAR signing and verification on candidate run 41107098417.
The public certificate SHA-256 is
`421cd80d80141ef72cc26235e415277e1af862ffe369234f7d04538f74ba2636`.
This proves key access, not compatibility with existing installations. Compare
with the original Shorebird bundle and test the installed-app upgrade path.
Keep credentials in GitHub's secure repository settings; never commit them or
silently substitute a disposable debug key.

Before claiming install-once updates:
1. Reconcile the intended guest-mode code with this repository and Android identity.
2. Build a signed Shorebird baseline with an explicit entrypoint and an unused version.
3. Install and test the actual APK on Android, including the intended backend.
4. Send a compatible staging patch and verify application after restart.
Native code, plugin, engine, or certain asset changes may require a new full package;
Dart code patches cannot guarantee every future change without a package update.

## Release hardening on the recovery branch

The branch now includes code changes for review; none have been deployed:
- Private Firestore profiles are readable only by their owner or an administrator.
  New profiles must use the application's trial defaults. Owners cannot promote
  themselves, grant paid access/credits, change permissions, or delete/recreate a
  profile to refill a quota. Normal profile, private settings, and social account
  sync fields remain writable. Analysis counters can increment by one only.
- The subcollection wildcard requires a collection segment, avoiding a rules-v2
  match on the parent profile that would otherwise bypass its restrictions.
- Android release builds require a real release signing configuration instead of
  silently falling back to the debug key. Debug builds do not require that key.
- App Check debug providers apply only to debug builds. Android production uses
  Play Integrity; Apple production uses App Attest with DeviceCheck fallback.
  Firebase provider configuration, signing fingerprints, distribution settings
  (including sideloading if used), and real-device validation remain required.

Validation: a local Firestore 1.22.0 emulator demonstrated six failing security
cases against the original rules (5/11 passed). After the fix and an additional
private settings test, all 12 tests passed. This uses a synthetic demo project,
not production data. `git diff --check` passed. Flutter analysis and tests are
defined in `scc_release_validation.yml`, pinned to Flutter 3.44.6; their result
passed in Actions on code commit `1fad8b4a0eef5df601862b586dc9d4b21d9d042e`:
analysis reported no issues, 88 Flutter tests passed and 6 optional live tests
were skipped. The 12 Firestore tests also passed on the GitHub runner.
Run: https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41099352116
The signed APK/AAB candidate build passed on source commit
`2f0f24a728aaea4955fff24867700d5ccee1d905`:
https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41110483983
Both packages passed signature/identity checks. See `ANDROID_CANDIDATE.md` for
exact file hashes and separate startup-test evidence. This is a standard Flutter
QA candidate; it is not a verified Shorebird OTA baseline.

The local Flutter bootstrap was stopped by automatic approval review because it
attempted to contact cloud instance metadata. It was not retried or bypassed;
the workflow runs analysis/tests on a separate GitHub runner without application
secrets. Firestore checks used only a local JVM emulator and test accounts.

The exact signed APK also installed and displayed its Arabic login screen on an
Android API 35 emulator during an offline launch and an online restart, with no
native process crash in either 35-second observation. Offline Google Fonts
loading produced non-fatal asynchronous errors; online restart did not show
those errors. This is a startup check only, not an authenticated backend test.
Evidence: https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41112804859

## Remaining launch blockers

- SHOREBIRD_TOKEN passed an authenticated GET of app metadata, including checks
  for the correct app ID and organization 52539. Release/patch write permission
  remains untested. Evidence:
  https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41099341611/job/124213323218
  All four Android signing secrets are now present and cryptographically usable.
  This resolves the missing-secret blocker. Original Shorebird bundle certificate
  continuity also passed; installed-app update compatibility remains untested:
  https://github.com/helalalfqih-sketch/smart_content_creator/actions/runs/41107098417
- Reconcile guest mode and the intended VPS backend with this Firebase/Supabase
  source before choosing a baseline version and making an OTA patch.
- Storage rules still have a permissive authenticated-user catchall, and catalog
  ownership needs a separate review. These changes are not a complete security
  audit or a declaration that the app is safe to launch.
- Client-managed subscription expiry, AI routing/permissions, and credit usage
  need trusted backend enforcement. Some legacy client writes to these protected
  fields will now be rejected. Do not deploy the rules until those flows and any
  public creator-profile feature have been reconciled and tested. A public view
  must not expose the private user document containing provider credentials.
- Address offline font loading; the standard Flutter QA candidate reached the
  login screen despite these logged errors. Authenticated/backend functionality,
  production App Check and physical-device/upgrade behavior remain untested.
- Build and confirm an updater-enabled Shorebird baseline, then verify a
  compatible staging patch after restart. The signed QA candidate above does
  not establish OTA support.

## How Shorebird relates to the VPS

GitHub Actions can build the app and publish releases/patches to Shorebird. The
VPS runs backend services and does not need a Shorebird key for that role. Apps
use `shorebird.yaml` to identify themselves and fetch updates from Shorebird;
their backend URL/configuration is a separate integration.

For organization-owned CI credentials, create a Shorebird service account named
`GitHub Actions` with the Developer role. Create its expiring API key and save it
directly in GitHub's repository secret `SHOREBIRD_TOKEN`. Test the new key before
revoking the previous personal key. On the current Hobby plan, use an API key;
keyless GitHub trust rules require Business or Enterprise. No new service account
or key was created as part of these code changes.

If builds must run on the VPS instead, install the project and its Flutter,
Shorebird, Java/Android SDK and release-signing prerequisites there, and inject
the service account key as the `SHOREBIRD_TOKEN` environment variable using a
restricted secret store. Do not put that key in the app, source, chat, or shell
history. A successful authenticated API read verifies access; it does not by
itself produce or publish a working app.

Official reference: https://docs.shorebird.dev/account/service-accounts/

No production release, patch, database-rule deployment, server deployment, or
merge has been performed by this recovery branch.
