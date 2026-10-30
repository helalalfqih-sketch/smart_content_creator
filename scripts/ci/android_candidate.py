#!/usr/bin/env python3
"""Prepare ephemeral signing files and verify Android QA artifacts.

Only public certificate fingerprints and artifact metadata leave the runner.
No command in this script publishes an app or modifies a backend.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APP_ID = "com.smartcontentcreator.app"
VERSION_NAME = "1.3.1-rc.1"
VERSION_CODE = "7"
BASELINE_SHA256 = "806329e11d00931db1c28dcb0700843f80e9bcc9ae4e6336b6813451cf9c2df9"


def run(command, *, env=None):
    result = subprocess.run(command, env=env, capture_output=True, check=False)
    if result.returncode:
        # Tool diagnostics may include signing properties: never echo them.
        raise RuntimeError(f"{Path(command[0]).name} failed (exit {result.returncode}).")
    return result.stdout


def digest(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def properties_value(value):
    # java.util.Properties supports ASCII with escaped UTF-16 code units.
    units = value.encode("utf-16-be")
    return "".join(f"\\u{int.from_bytes(units[i:i+2], 'big'):04x}" for i in range(0, len(units), 2))


def private_dir():
    return Path(os.environ["RUNNER_TEMP"]) / "scc-android-signing"


def keytool(*args, env=None):
    return run(["keytool", "-J-Duser.language=en", "-J-Duser.country=US", *args], env=env)


def prepare():
    os.umask(0o077)
    directory = private_dir()
    directory.mkdir(mode=0o700, exist_ok=False)
    (directory / "owner.txt").write_text(str(ROOT.resolve()))
    env = os.environ.copy()
    for name in ("KEYSTORE_PASSWORD", "KEY_PASSWORD", "KEY_ALIAS"):
        value = env.get(name, "").rstrip("\r\n")
        if not value or "\n" in value or "\r" in value:
            raise RuntimeError(f"{name} is missing or invalid.")
        env[name] = value
    encoded = "".join(env.get("KEYSTORE_BASE64", "").lstrip("\ufeff").split())
    if not encoded:
        raise RuntimeError("KEYSTORE_BASE64 is missing.")
    try:
        material = base64.b64decode(encoded, validate=True)
    except (ValueError, UnicodeError):
        raise RuntimeError("KEYSTORE_BASE64 is not valid Base64.") from None
    if not material:
        raise RuntimeError("Decoded keystore is empty.")
    keystore = directory / "upload.jks"
    keystore.write_bytes(material)
    env.pop("KEYSTORE_BASE64", None)
    certificate = keytool("-exportcert", "-alias", env["KEY_ALIAS"], "-keystore", str(keystore), "-storepass:env", "KEYSTORE_PASSWORD", env=env)
    certificate_sha = hashlib.sha256(certificate).hexdigest()
    # A successful certificate export tests only the store password. Actually
    # sign a temporary JAR to validate private-key access and KEY_PASSWORD too.
    probe = directory / "signing-probe.jar"
    with zipfile.ZipFile(probe, "w") as archive:
        archive.writestr("probe.txt", "Android signing validation only\n")
    run(["jarsigner", "-keystore", str(keystore), "-storepass:env", "KEYSTORE_PASSWORD", "-keypass:env", "KEY_PASSWORD", str(probe), env["KEY_ALIAS"]], env=env)
    verified = run(["jarsigner", "-J-Duser.language=en", "-verify", str(probe)]).decode()
    if "jar verified." not in verified:
        raise RuntimeError("The temporary signing probe did not verify.")
    properties = ROOT / "android/key.properties"
    if properties.exists():
        raise RuntimeError("Refusing to replace an existing android/key.properties.")
    fields = {"storeFile": str(keystore), "storePassword": env["KEYSTORE_PASSWORD"], "keyPassword": env["KEY_PASSWORD"], "keyAlias": env["KEY_ALIAS"]}
    with properties.open("x", encoding="ascii") as output:
        output.write("".join(f"{key}={properties_value(value)}\n" for key, value in fields.items()))
    (directory / "properties-sha256.txt").write_text(digest(properties))
    (directory / "certificate-sha256.txt").write_text(certificate_sha)
    print("Keystore, alias, store password and private-key signing verified.")
    print(f"Signing certificate SHA-256: {certificate_sha}")


def android_tool(name):
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    candidates = [p for p in (sdk / "build-tools").iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", p.name) and (p / name).is_file()]
    if not candidates:
        raise RuntimeError(f"Android SDK tool {name} is unavailable.")
    return str(max(candidates, key=lambda p: tuple(map(int, p.name.split(".")))) / name)


def apk_certificate(path):
    output = run([android_tool("apksigner"), "verify", "--print-certs", str(path)]).decode()
    signers = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)", output)
    if len(signers) != 1:
        raise RuntimeError("Expected exactly one APK signer.")
    return signers[0].lower()


def apk_identity(path):
    output = run([android_tool("aapt"), "dump", "badging", str(path)]).decode()
    match = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", output, re.MULTILINE)
    if not match:
        raise RuntimeError("Could not read APK identity.")
    return dict(zip(("application_id", "version_code", "version_name"), match.groups()))


def compare_baseline():
    directory = private_dir()
    apk = Path(os.environ["RUNNER_TEMP"]) / "scc-v1.3.0-arm64.apk"
    if digest(apk) != BASELINE_SHA256:
        raise RuntimeError("Published v1.3.0 APK checksum mismatch.")
    identity = apk_identity(apk)
    if identity["application_id"] != APP_ID:
        raise RuntimeError("Published baseline APK has an unexpected application ID.")
    baseline_cert = apk_certificate(apk)
    current_cert = (directory / "certificate-sha256.txt").read_text()
    result = {"reference": "GitHub v1.3.0 ARM64 APK (not a verified Shorebird baseline)", "reference_sha256": BASELINE_SHA256, "reference_identity": identity, "reference_certificate_sha256": baseline_cert, "candidate_certificate_sha256": current_cert, "certificate_matches_reference": baseline_cert == current_cert}
    output = ROOT / "build/candidate-report"
    output.mkdir(parents=True, exist_ok=True)
    (output / "signing-comparison.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    if baseline_cert != current_cert:
        raise RuntimeError("Signing certificate differs from the published v1.3.0 APK; stop for baseline review.")


def verify_artifacts():
    directory = private_dir()
    expected_cert = (directory / "certificate-sha256.txt").read_text()
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    aab = ROOT / "build/app/outputs/bundle/release/app-release.aab"
    expected_identity = {"application_id": APP_ID, "version_code": VERSION_CODE, "version_name": VERSION_NAME}
    if apk_identity(apk) != expected_identity or apk_certificate(apk) != expected_cert:
        raise RuntimeError("APK identity or signing certificate does not match the locked candidate.")
    verification = run(["jarsigner", "-J-Duser.language=en", "-verify", str(aab)]).decode()
    if "jar verified." not in verification:
        raise RuntimeError("AAB JAR signature did not verify.")
    certs = keytool("-printcert", "-rfc", "-jarfile", str(aab)).decode()
    pem = re.search(r"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----", certs, re.DOTALL)
    if not pem or hashlib.sha256(base64.b64decode(pem[1])).hexdigest() != expected_cert:
        raise RuntimeError("AAB signing certificate differs from the verified keystore.")
    bundletool = str(Path(os.environ["RUNNER_TEMP"]) / "bundletool.jar")
    run(["java", "-jar", bundletool, "validate", f"--bundle={aab}"])
    manifest = ET.fromstring(run(["java", "-jar", bundletool, "dump", "manifest", f"--bundle={aab}"]))
    android = "{http://schemas.android.com/apk/res/android}"
    identity = {"application_id": manifest.get("package"), "version_code": manifest.get(android + "versionCode"), "version_name": manifest.get(android + "versionName")}
    if identity != expected_identity:
        raise RuntimeError("AAB identity does not match the locked candidate.")
    run(["git", "diff", "--exit-code", "--", "pubspec.lock"])
    report = {"commit_sha": os.environ["GITHUB_SHA"], "identity": identity, "entrypoint": "lib/main.dart", "flavor": None, "dart_defines": [], "backend": "Existing repository Firebase/Supabase configuration; VPS guest migration not applied", "certificate_sha256": expected_cert, "flutter_version": "3.44.6", "shorebird_release_published": False, "ota_baseline_verified": False, "device_smoke_tested": False, "artifacts": [{"name": p.name, "bytes": p.stat().st_size, "sha256": digest(p)} for p in (apk, aab)]}
    output = ROOT / "build/candidate-report"
    (output / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    (output / "README.txt").write_text("Signed QA candidate only. No GitHub or Shorebird release was published.\nBuilt with standard Flutter: this is NOT a verified Shorebird OTA baseline.\nDo not distribute as production or assume device/backend compatibility.\n")
    print(json.dumps(report, indent=2))


def cleanup():
    directory = private_dir()
    marker = directory / "owner.txt"
    if directory.is_symlink() or not marker.is_file():
        return
    if marker.read_text() != str(ROOT.resolve()):
        raise RuntimeError("Refusing to clean another workspace's signing files.")
    properties = ROOT / "android/key.properties"
    expected_hash = directory / "properties-sha256.txt"
    if expected_hash.exists() and properties.exists():
        if digest(properties) != expected_hash.read_text():
            raise RuntimeError("Refusing to delete a signing configuration changed by another process.")
        properties.unlink()
    shutil.rmtree(directory)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("prepare", "compare-baseline", "verify", "cleanup"))
    args = parser.parse_args()
    try:
        {"prepare": prepare, "compare-baseline": compare_baseline, "verify": verify_artifacts, "cleanup": cleanup}[args.action]()
    except UnicodeError:
        print("Android candidate check failed: invalid credential encoding.", file=sys.stderr)
        sys.exit(1)
    except (RuntimeError, OSError, ValueError, KeyError, ET.ParseError) as error:
        print(f"Android candidate check failed: {error}", file=sys.stderr)
        sys.exit(1)
