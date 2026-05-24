package com.example.sentinel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sentinel.app/sos"

    override fun onResume() {
        super.onResume()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "ACTION_TRIGGER_SOS") {
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod("triggerSos", null)
            }
            // Clear the action so it doesn't trigger again
            intent.action = ""
        }
    }
}
