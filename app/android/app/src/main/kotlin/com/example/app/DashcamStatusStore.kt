package com.example.app

import android.content.Context
import android.content.Intent
import android.os.Environment
import android.os.StatFs
import androidx.core.content.ContextCompat

object DashcamStatusStore {
    var onStatus: ((Map<String, Any>) -> Unit)? = null

    private var isRecording: Boolean = false
    private var elapsedSeconds: Int = 0
    private var storageUsedMb: Int = 0
    private var lastSegment: String = "-"
    private var lastSegmentLocked: Boolean = false
    private var warning: String = ""
    var isFrontCamera: Boolean = false

    fun startRecording(context: Context) {
        if (isRecording) return
        val intent = Intent(context, DashcamForegroundService::class.java).apply {
            action = DashcamForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(context, intent)
        isRecording = true
        elapsedSeconds = 0
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

    fun onSegmentFinalized(segmentName: String, usedMb: Int, isLocked: Boolean, context: Context) {
        storageUsedMb = usedMb
        lastSegment = segmentName
        lastSegmentLocked = isLocked
        
        val freeSpaceMb = getFreeStorageMb(context)
        if (freeSpaceMb < 500) {
            warning = "Spazio in esaurimento (< 500MB)."
        } else {
            warning = ""
        }
        emitCurrent(context)
    }

    fun onStopped(context: Context) {
        isRecording = false
        elapsedSeconds = 0
        emitCurrent(context)
    }

    fun onWarning(message: String, context: Context) {
        warning = message
        emitCurrent(context)
    }

    fun getFreeStorageMb(context: Context?): Int {
        return try {
            val path = Environment.getExternalStorageDirectory()
            val stat = StatFs(path.path)
            val blockSize = stat.blockSizeLong
            val availableBlocks = stat.availableBlocksLong
            ((availableBlocks * blockSize) / (1024 * 1024)).toInt()
        } catch (e: Exception) {
            0
        }
    }

    fun emitCurrent(context: Context? = null) {
        onStatus?.invoke(
            mapOf(
                "isRecording" to isRecording,
                "elapsedSeconds" to elapsedSeconds,
                "storageUsedMb" to storageUsedMb, // Used by dashcam videos
                "freeStorageMb" to getFreeStorageMb(context), // Actual device free space
                "lastSegment" to lastSegment,
                "lastSegmentLocked" to lastSegmentLocked,
                "warning" to warning,
                "isFrontCamera" to isFrontCamera
            )
        )
    }
}
