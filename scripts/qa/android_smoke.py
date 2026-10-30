#!/usr/bin/env python3
"""Launch an existing signed candidate without signing keys or account login."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

APP_ID = "com.smartcontentcreator.app"
OUTPUT = Path("build/android-smoke")


def adb(*args, timeout=60):
    result = subprocess.run(["adb", *args], capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Android command failed: {args[0]}")
    return result.stdout


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def launch(label, activity):
    adb("shell", "am", "force-stop", APP_ID)
    adb("logcat", "-c")
    started = adb("shell", "am", "start", "-W", "-n", activity).decode()
    if "Status: ok" not in started:
        raise RuntimeError(f"Activity did not start ({label}).")
    # This is a bounded observation window, not an assertion about rendering.
    time.sleep(35)
    screenshot = OUTPUT / f"{label}.png"
    screenshot.write_bytes(adb("exec-out", "screencap", "-p"))
    pid = adb("shell", "pidof", APP_ID).decode().strip()
    activities = adb("shell", "dumpsys", "activity", "activities").decode()
    resumed = any(APP_ID in line and ("ResumedActivity" in line or "topResumedActivity" in line) for line in activities.splitlines())
    crashes = adb("logcat", "-d", "-b", "crash").decode(errors="replace")
    app_crashed = f"Process: {APP_ID}," in crashes
    errors = adb("logcat", "-d", "-s", "flutter:E", "AndroidRuntime:E").decode(errors="replace")
    (OUTPUT / f"{label}-errors.txt").write_text(errors)
    print(f"SMOKE_ERRORS_BEGIN {label}\n{errors[-12000:]}\nSMOKE_ERRORS_END", flush=True)
    result = {"scenario": label, "process_alive": bool(pid), "activity_resumed": resumed, "native_crash_detected": app_crashed, "unhandled_flutter_error_logged": "Unhandled Exception" in errors, "observed_seconds": 35, "screenshot": screenshot.name, "screen_reviewed": False}
    if not pid or not resumed or app_crashed:
        raise RuntimeError(f"Startup smoke failed ({label}): process={bool(pid)}, resumed={resumed}, crash={app_crashed}.")
    return result


def main():
    source_sha = os.environ["CANDIDATE_SHA"]
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise RuntimeError("Invalid expected candidate commit.")
    candidates = list(Path("candidate").rglob("candidate.json"))
    apks = list(Path("candidate").rglob("app-release.apk"))
    if len(candidates) != 1 or len(apks) != 1:
        raise RuntimeError("Expected one verified report and one APK.")
    candidate = json.loads(candidates[0].read_text())
    expected = {"application_id": APP_ID, "version_code": "7", "version_name": "1.3.1-rc.1"}
    apk_entry = next(a for a in candidate["artifacts"] if a["name"] == "app-release.apk")
    if candidate["commit_sha"] != source_sha or candidate["identity"] != expected or sha256(apks[0]) != apk_entry["sha256"]:
        raise RuntimeError("Downloaded APK does not match the reviewed candidate.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {"candidate_commit": source_sha, "test_commit": os.environ["GITHUB_SHA"], "apk_sha256": apk_entry["sha256"], "identity": expected, "device": "Android API 35 Google APIs x86_64 emulator", "account_login_tested": False, "production_attestation_tested": False, "backend_functionality_tested": False, "ota_patch_tested": False, "checks": []}
    try:
        if "Success" not in adb("install", "-r", str(apks[0]), timeout=180).decode():
            raise RuntimeError("APK installation failed.")
        package = adb("shell", "dumpsys", "package", APP_ID).decode()
        if not re.search(r"versionCode=7\b", package) or "versionName=1.3.1-rc.1" not in package:
            raise RuntimeError("Installed package version differs from the candidate.")
        activity = adb("shell", "cmd", "package", "resolve-activity", "--brief", APP_ID).decode().strip().splitlines()[-1]
        if not activity.startswith(APP_ID + "/"):
            raise RuntimeError("Unexpected launcher activity.")
        adb("shell", "svc", "wifi", "disable")
        adb("shell", "svc", "data", "disable")
        report["checks"].append(launch("offline-launch", activity))
        adb("shell", "svc", "wifi", "enable")
        adb("shell", "svc", "data", "enable")
        time.sleep(5)
        report["checks"].append(launch("online-restart", activity))
        report["result"] = "passed_process_and_activity_checks"
    except Exception as error:
        report["result"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        (OUTPUT / "smoke.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2), flush=True)
        # These clean-install screens contain no signed-in user's data. Emit
        # them for review as well as retaining the PNGs in the Actions artifact.
        for screenshot in sorted(OUTPUT.glob("*.png")):
            print(f"SMOKE_SCREENSHOT_BEGIN {screenshot.name}", flush=True)
            print(base64.b64encode(screenshot.read_bytes()).decode(), flush=True)
            print("SMOKE_SCREENSHOT_END", flush=True)


if __name__ == "__main__":
    main()
