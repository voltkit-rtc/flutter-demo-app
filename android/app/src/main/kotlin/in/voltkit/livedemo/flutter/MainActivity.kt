package `in`.voltkit.livedemo.flutter

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Starts and stops [LiveCallService] for Dart. See lib/rtc/call_service.dart. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        LiveCallService.onLeave = { runOnUiThread { channel.invokeMethod("leave", null) } }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, LiveCallService::class.java)
                        .putExtra(LiveCallService.EXTRA_TITLE, call.argument<String>("title"))
                        .putExtra(LiveCallService.EXTRA_TEXT, call.argument<String>("text"))
                        .putExtra(LiveCallService.EXTRA_LEAVE, call.argument<String>("leaveLabel"))
                    try {
                        // startService, not startForegroundService: the service promotes itself at once, and if
                        // Android refuses, a service started the other way would crash the app.
                        startService(intent)
                        result.success(true)
                    } catch (error: RuntimeException) {
                        // The room still works while the app is open: only the background is lost.
                        result.error("refused", error.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, LiveCallService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        LiveCallService.onLeave = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "voltkit_live/call_service"
    }
}
