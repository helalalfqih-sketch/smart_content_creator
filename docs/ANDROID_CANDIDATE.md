# Signed Android validation candidate

This workflow validates the recovered Android signing identity and produces
reviewable APK/AAB files. It does not publish to GitHub Releases, Google Play,
Shorebird, or any backend, and does not merge the recovery branch.

## Locked build

| Setting | Value |
| --- | --- |
| Source | Exact `github.sha` on `codex/shorebird-recovery-20261030` |
| Flutter | 3.44.6 |
| Java | Temurin 21 |
| Target / mode | `lib/main.dart` / release |
| Flavor / Dart defines | None |
| Application ID | `com.smartcontentcreator.app` |
| Candidate version | `1.3.1-rc.1+7` (command-line override only) |
| Backend | Current repository Firebase/Supabase configuration |
| Signing source | Four existing GitHub repository secrets |
| Outputs | APK, AAB, public signing comparison and checksums |

This is built with standard Flutter to validate Android signing and native
compilation. It is **not** a verified Shorebird OTA baseline. Adding
`shorebird.yaml` to an APK does not prove that it contains the Shorebird engine.
No guest-mode/VPS migration is included, and device/backend smoke tests remain
required. Do not distribute this candidate as production.

## Checks and credential handling

1. Exercise signing failures and cleanup with disposable unit-test keys.
2. Decode the repository keystore into the disposable runner's private temp
   directory. Check the alias/store password, then sign and verify a temporary
   JAR to check private-key access and the key password.
3. Record the published v1.3.0 ARM64 APK's identity, certificate and verified
   SHA-256. The first candidate run confirmed that its application ID differs
   from the current repository, so it is not the authoritative OTA reference.
   Fetch the original AAB for Shorebird release 783074 (`1.3.0+6`) using GET
   requests only. Check its server-reported digest/size, application/version
   identity and signing certificate against the recovered key. Any mismatch
   with this Shorebird bundle stops the build for review. Matching an uploaded
   bundle does not prove the certificate of a Play App Signing installation;
   the actual installed APK/update path still needs testing.
4. Build the APK and AAB using locked dependencies. Verify both package
   identities, their signatures/certificates, AAB structure, checksums and
   unchanged dependency lockfile.
   The build commands keep Flutter's pub-enabled path so Flutter 3.44.6
   regenerates Android plugin registration for release mode, excluding
   development-only plugins such as `integration_test`. Using `--no-pub`
   after a normal pub get leaves stale development-mode registration.
5. Delete only signing files owned by this run, even on failure. Retain only
   explicit APK/AAB/report paths as seven-day Actions artifacts. No keystore,
   password, private-key export, or key.properties is uploaded or printed.

The workflow uses read-only repository permissions. SHOREBIRD_TOKEN is passed
only to the original-release lookup step, and only to api.shorebird.dev.
Storage downloads use a separate request without that authorization header;
signed download URLs are never printed. Shorebird CLI 1.6.134's release dry-run was reviewed:
although it does not publish a release, its default managed patch-signing key
lookup can create the organization's key on first use. Any such account change
and the eventual release/patch require a separately reviewed next step.

Official implementation references:
- https://github.com/shorebirdtech/shorebird/blob/v1.6.134/packages/shorebird_cli/lib/src/commands/release/release_command.dart
- https://github.com/shorebirdtech/shorebird/blob/v1.6.134/packages/shorebird_code_push_client/lib/src/code_push_client.dart

Run signing-helper tests with a full JDK (not a JRE):

```sh
python3 -m unittest discover -s scripts/ci -p 'test_android_candidate.py' -v
```

Publishing and install/update/OTA checks are not inferred from a successful
candidate build. Read `candidate.json` and the Actions logs for the exact source,
identity, signing certificate, artifact digests and untested boundaries.

## Android startup smoke check

The separate `scc_android_smoke.yml` workflow downloads the exact candidate
artifact from the build run named in its configuration. It checks the APK's
digest against `candidate.json`, its source commit, and the installed package
version before launch. It needs only read access to Actions artifacts; no
Android signing or Shorebird credentials are passed to this job.

On an Android API 35 Google APIs x86_64 emulator, it observes a clean offline
launch and a restart with networking enabled for 35 seconds each. It records
process/activity survival, native crashes, Flutter error logs and screenshots.
The screenshots require visual review: a live process alone does not establish
that the intended screen rendered. `smoke.json` identifies both the candidate
and test commits and records the limited checks actually performed.

No user account is entered or created. Successful startup does not test login,
backend functionality, Play Integrity acceptance, an update over an existing
installation, ARM hardware, or any Shorebird patch. These remain separate
release checks. Evidence is retained as a seven-day Actions artifact.
