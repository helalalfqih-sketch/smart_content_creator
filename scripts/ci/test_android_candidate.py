"""Exercise real keytool/jarsigner failure boundaries with disposable test keys."""
import base64
import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import android_candidate as candidate


class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = tempfile.TemporaryDirectory()
        key = Path(cls.fixture.name) / "fixture.jks"
        cls.credentials = {"KEYSTORE_PASSWORD": "fixture-store-pass", "KEY_PASSWORD": "fixture-key-pass", "KEY_ALIAS": "fixture"}
        candidate.keytool("-genkeypair", "-keystore", str(key), "-storetype", "JKS", "-alias", "fixture", "-keyalg", "RSA", "-keysize", "2048", "-validity", "1", "-dname", "CN=Ephemeral CI Test", "-storepass:env", "KEYSTORE_PASSWORD", "-keypass:env", "KEY_PASSWORD", "-noprompt", env={**os.environ, **cls.credentials})
        cls.credentials["KEYSTORE_BASE64"] = base64.b64encode(key.read_bytes()).decode()

    @classmethod
    def tearDownClass(cls):
        cls.fixture.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "android").mkdir()
        self.env = patch.dict(os.environ, {**self.credentials, "RUNNER_TEMP": self.temp.name})
        self.env.start()
        self.root_patch = patch.object(candidate, "ROOT", self.root)
        self.root_patch.start()

    def tearDown(self):
        self.root_patch.stop()
        self.env.stop()
        self.temp.cleanup()

    def prepare(self):
        with contextlib.redirect_stdout(io.StringIO()):
            candidate.prepare()

    def test_sign_and_load_properties_then_clean(self):
        self.prepare()
        source = self.root / "CheckProperties.java"
        source.write_text('''import java.util.*; import java.io.*;
class CheckProperties { public static void main(String[] a) throws Exception {
Properties p = new Properties(); try (var f = new FileInputStream(a[0])) { p.load(f); }
if (!p.getProperty("storePassword").equals(System.getenv("KEYSTORE_PASSWORD")) ||
!p.getProperty("keyPassword").equals(System.getenv("KEY_PASSWORD")) ||
!p.getProperty("keyAlias").equals(System.getenv("KEY_ALIAS")) ||
!new File(p.getProperty("storeFile")).isFile()) { System.exit(1); }
}}''')
        candidate.run(["java", str(source), str(self.root / "android/key.properties")])
        candidate.cleanup()
        self.assertFalse((self.root / "android/key.properties").exists())
        self.assertFalse(candidate.private_dir().exists())

    def test_windows_base64_whitespace(self):
        os.environ["KEYSTORE_BASE64"] = "\ufeff\r\n " + self.credentials["KEYSTORE_BASE64"] + "\r\n"
        self.prepare()
        candidate.cleanup()

    def test_invalid_base64_fails_without_properties(self):
        os.environ["KEYSTORE_BASE64"] = "%%%INVALID%%%"
        with self.assertRaisesRegex(RuntimeError, "not valid Base64"):
            self.prepare()
        candidate.cleanup()
        self.assertFalse((self.root / "android/key.properties").exists())

    def test_wrong_store_password(self):
        os.environ["KEYSTORE_PASSWORD"] = "wrong-secret"
        with self.assertRaisesRegex(RuntimeError, "keytool failed") as raised:
            self.prepare()
        self.assertNotIn("wrong-secret", str(raised.exception))
        candidate.cleanup()

    def test_wrong_private_key_password(self):
        os.environ["KEY_PASSWORD"] = "wrong-secret"
        with self.assertRaisesRegex(RuntimeError, "jarsigner failed"):
            self.prepare()
        candidate.cleanup()

    def test_wrong_alias(self):
        os.environ["KEY_ALIAS"] = "missing-alias"
        with self.assertRaisesRegex(RuntimeError, "keytool failed"):
            self.prepare()
        candidate.cleanup()

    def test_existing_properties_are_never_deleted(self):
        properties = self.root / "android/key.properties"
        properties.write_text("existing configuration")
        with self.assertRaisesRegex(RuntimeError, "Refusing to replace"):
            self.prepare()
        candidate.cleanup()
        self.assertEqual(properties.read_text(), "existing configuration")

    def test_changed_properties_are_never_deleted(self):
        self.prepare()
        properties = self.root / "android/key.properties"
        properties.write_text("changed configuration")
        with self.assertRaisesRegex(RuntimeError, "changed by another process"):
            candidate.cleanup()
        self.assertTrue(properties.exists())


if __name__ == "__main__":
    unittest.main()
