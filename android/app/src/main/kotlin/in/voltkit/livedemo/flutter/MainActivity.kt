package `in`.voltkit.livedemo.flutter

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Starts and stops [LiveCallService] for Dart, and describes the phone for a sound report. See lib/rtc/call_service.dart. */
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
                // For a sound report: VoltKit asks for the phone, its Android version and the call volume.
                "device" -> {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "android" to Build.VERSION.RELEASE,
                            "sdk" to Build.VERSION.SDK_INT,
                            "callVolume" to audio.getStreamVolume(AudioManager.STREAM_VOICE_CALL),
                            "callVolumeMax" to audio.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
                            "route" to route(audio),
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Where call sound plays right now, as Android has it. */
    @Suppress("DEPRECATION")
    private fun route(audio: AudioManager): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return when (audio.communicationDevice?.type) {
                AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "loudspeaker"
                AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
                AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_USB_HEADSET -> "wired headset"
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLE_HEADSET -> "Bluetooth headset"
                null -> "none"
                else -> "other (type ${audio.communicationDevice?.type})"
            }
        }
        return when {
            audio.isBluetoothScoOn -> "Bluetooth headset"
            audio.isWiredHeadsetOn -> "wired headset"
            audio.isSpeakerphoneOn -> "loudspeaker"
            else -> "earpiece"
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
