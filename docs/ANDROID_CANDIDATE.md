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
3. Download the published v1.3.0 ARM64 APK and verify its known SHA-256. Compare
   its application ID and signing certificate with the supplied keystore.
   A mismatch stops the build for review; it does not prove which key belongs
   to the user's currently installed app. This APK is not the verified
   Shorebird baseline (see `SHOREBIRD_RECOVERY.md`).
4. Build the APK and AAB using locked dependencies. Verify both package
   identities, their signatures/certificates, AAB structure, checksums and
   unchanged dependency lockfile.
5. Delete only signing files owned by this run, even on failure. Retain only
   explicit APK/AAB/report paths as seven-day Actions artifacts. No keystore,
   password, private-key export, or key.properties is uploaded or printed.

The workflow uses read-only repository permissions. It intentionally does not
receive SHOREBIRD_TOKEN. Shorebird CLI 1.6.134's release dry-run was reviewed:
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
