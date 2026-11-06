package `in`.voltkit.livedemo.flutter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Keeps a room or call alive while the app is in the background or the screen is off. Without a foreground service,
 * Android cuts the app's network and microphone a few seconds after it leaves the screen.
 *
 * The notification opens the app and has a Leave action. Swiping the app away ends the room, like the React Native
 * demo: Dart hears the same `leave`.
 */
class LiveCallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_LEAVE) {
            onLeave?.invoke()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "VoltKit Live"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val leave = intent?.getStringExtra(EXTRA_LEAVE) ?: "Leave"
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(title, text, leave), serviceType())
        } catch (error: RuntimeException) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        onLeave?.invoke()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    /**
     * Microphone once it may be used, so someone on stage keeps talking in the background. A listener who never gave
     * that permission runs as media playback: Android 14 refuses the microphone type without it.
     */
    private fun serviceType(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        val mic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        return if (mic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        }
    }

    private fun notification(title: String, text: String, leaveLabel: String): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Live rooms and calls", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                    enableVibration(false)
                    setSound(null, null)
                },
            )
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val leave = PendingIntent.getService(
            this,
            1,
            Intent(this, LiveCallService::class.java).setAction(ACTION_LEAVE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_call_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .apply { if (open != null) setContentIntent(open) }
            .addAction(0, leaveLabel, leave)
            .build()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_LEAVE = "leaveLabel"
        private const val ACTION_LEAVE = "in.voltkit.livedemo.flutter.LEAVE"
        private const val CHANNEL_ID = "voltkit_live_calls"
        private const val NOTIFICATION_ID = 7301

        /** Set by [MainActivity]. Null when no Flutter engine is running. */
        @Volatile var onLeave: (() -> Unit)? = null
    }
}
