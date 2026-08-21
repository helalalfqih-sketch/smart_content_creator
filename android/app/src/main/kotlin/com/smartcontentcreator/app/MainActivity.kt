package com.smartcontentcreator.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            val prefs = getSharedPreferences("com.google.firebase.appcheck.debug.DebugAppCheckProvider", MODE_PRIVATE)
            prefs.edit().putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", "9698af27-3d92-4c89-91fb-236dbedf38d6").apply()
        } catch (_: Exception) {
        }
        super.onCreate(savedInstanceState)
    }
}
