package com.example.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

object DashcamStatusStore {
    var onStatus: ((Map<String, Any>) -> Unit)? = null

    private var isRecording: Boolean = false
    private var isPaused: Boolean = false
    private var elapsedSeconds: Int = 0
    private var storageUsedMb: Int = 0
    private var lastSegment: String = "-"
    private var lastSegmentLocked: Boolean = false
    private var warning: String = ""
    private var liveSpeedKmh: Double = 0.0
    private var lowStorageNotificationSent: Boolean = false
    private var cachedFreeStorageMb: Int = 0
    private var lastFreeStorageReadAtMs: Long = 0L
    var isFrontCamera: Boolean = false

    fun startRecording(context: Context) {
        if (isRecording) return
        val intent = Intent(context, DashcamForegroundService::class.java).apply {
            action = DashcamForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(context, intent)
        isRecording = true
        isPaused = false
        elapsedSeconds = 0
        liveSpeedKmh = 0.0
        warning = ""
        emitCurrent(context)
    }

    fun stopRecording(context: Context) {
        if (!isRecording) return
        val intent = Intent(context, DashcamForegroundService::class.java).apply {
            action = DashcamForegroundService.ACTION_STOP
        }
        context.startService(intent)
        isRecording = false
        isPaused = false
        liveSpeedKmh = 0.0
        emitCurrent(context)
    }

    fun pauseRecording(context: Context) {
        if (!isRecording || isPaused) return
        isPaused = true
        emitCurrent(context)
    }

    fun resumeRecording(context: Context) {
        if (!isRecording || !isPaused) return
        isPaused = false
        emitCurrent(context)
    }

    fun lockIncident(context: Context) {
        val intent = Intent(context, DashcamForegroundService::class.java).apply {
            action = DashcamForegroundService.ACTION_LOCK_INCIDENT
        }
        context.startService(intent)
    }

    fun setCameraLens(isFront: Boolean, context: Context) {
        isFrontCamera = isFront
        emitCurrent(context)
    }

    fun onTick(seconds: Int, context: Context) {
        elapsedSeconds = seconds
        emitCurrent(context)
    }

    fun updateLiveSpeed(speedKmh: Double) {
        liveSpeedKmh = speedKmh.coerceIn(0.0, 250.0)
    }

    fun getLiveSpeedKmh(): Double {
        return liveSpeedKmh
    }

    fun isRecordingActive(): Boolean {
        return isRecording
    }

    fun isPausedState(): Boolean {
        return isPaused
    }

    fun notifyRecordingStarted(context: Context) {
        ensureAlertsChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            4101,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, ALERTS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("Recording started")
            .setContentText("Dashcam is recording in background")
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        manager.notify(RECORDING_STARTED_NOTIFICATION_ID, notification)
    }

    fun onSegmentFinalized(segmentName: String, usedMb: Int, isLocked: Boolean, context: Context) {
        storageUsedMb = usedMb
        lastSegment = segmentName
        lastSegmentLocked = isLocked
        emitCurrent(context)
    }

    fun onStopped(context: Context) {
        isRecording = false
        isPaused = false
        elapsedSeconds = 0
        liveSpeedKmh = 0.0
        emitCurrent(context)
    }

    fun onWarning(message: String, context: Context) {
        warning = message
        emitCurrent(context)
    }

    fun getFreeStorageMb(context: Context?): Int {
        val now = System.currentTimeMillis()
        if (cachedFreeStorageMb > 0 && now - lastFreeStorageReadAtMs < STORAGE_REFRESH_INTERVAL_MS) {
            return cachedFreeStorageMb
        }
        return try {
            val path = Environment.getExternalStorageDirectory()
            val stat = StatFs(path.path)
            val blockSize = stat.blockSizeLong
            val availableBlocks = stat.availableBlocksLong
            ((availableBlocks * blockSize) / (1024 * 1024)).toInt().also {
                cachedFreeStorageMb = it
                lastFreeStorageReadAtMs = now
            }
        } catch (e: Exception) {
            cachedFreeStorageMb
        }
    }

    fun emitCurrent(context: Context? = null) {
        val freeStorageMb = getFreeStorageMb(context)
        if (freeStorageMb <= LOW_STORAGE_THRESHOLD_MB) {
            if (warning.isBlank() || warning.startsWith("Remaining storage")) {
                warning = "Remaining storage <= 5GB."
            }
            if (context != null && !lowStorageNotificationSent) {
                notifyLowStorage(context, freeStorageMb)
                lowStorageNotificationSent = true
            }
        } else {
            if (warning.startsWith("Remaining storage")) {
                warning = ""
            }
            if (freeStorageMb >= LOW_STORAGE_RESET_MB) {
                lowStorageNotificationSent = false
            }
        }

        onStatus?.invoke(
            mapOf(
                "isRecording" to isRecording,
                "isPaused" to isPaused,
                "elapsedSeconds" to elapsedSeconds,
                "storageUsedMb" to storageUsedMb, // Used by dashcam videos
                "freeStorageMb" to freeStorageMb, // Actual device free space
                "lastSegment" to lastSegment,
                "lastSegmentLocked" to lastSegmentLocked,
                "warning" to warning,
                "isFrontCamera" to isFrontCamera,
                "speedKmh" to liveSpeedKmh,
            )
        )
    }

    private fun notifyLowStorage(context: Context, freeStorageMb: Int) {
        ensureAlertsChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            4102,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val freeGb = freeStorageMb.toDouble() / 1024.0
        val notification = NotificationCompat.Builder(context, ALERTS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("Storage almost full")
            .setContentText(String.format("%.1f GB free remaining", freeGb))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        manager.notify(LOW_STORAGE_NOTIFICATION_ID, notification)
    }

    private fun ensureAlertsChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            ALERTS_CHANNEL_ID,
            "Dashcam Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts for recording start and low storage"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private const val LOW_STORAGE_THRESHOLD_MB = 5 * 1024
    private const val LOW_STORAGE_RESET_MB = 6 * 1024
    private const val ALERTS_CHANNEL_ID = "dashcam_alerts"
    private const val LOW_STORAGE_NOTIFICATION_ID = 7101
    private const val RECORDING_STARTED_NOTIFICATION_ID = 7102
    private const val STORAGE_REFRESH_INTERVAL_MS = 10_000L
}
