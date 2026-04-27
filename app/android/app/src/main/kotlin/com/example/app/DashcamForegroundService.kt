package com.example.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.PendingRecording
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DashcamForegroundService : LifecycleService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var elapsedSeconds = 0
    private var running = false
    private var paused = false
    private var usedMb = 0
    private var rollingToNextSegment = false
    private var currentSegmentLocked = false
    private var pendingServiceStop = false

    private var cameraProvider: ProcessCameraProvider? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var currentRecording: Recording? = null
    private var currentSegmentFile: File? = null
    private var currentSegmentName: String = ""

    private data class SegmentMeta(
        val uri: Uri?,
        val file: File?,
        val name: String,
        var sizeMb: Int,
        var locked: Boolean,
    )

    private val segments: MutableList<SegmentMeta> = mutableListOf()

    private val ticker = object : Runnable {
        override fun run() {
            if (!running) {
                return
            }
            if (!paused) {
                elapsedSeconds += 1
                DashcamStatusStore.onTick(elapsedSeconds, this@DashcamForegroundService)
                updateNotification()
            }
            mainHandler.postDelayed(this, 1000)
        }
    }

    private val segmentRollover = object : Runnable {
        override fun run() {
            if (!running) {
                return
            }
            if (!paused) {
                rollToNextSegment()
            }
            mainHandler.postDelayed(this, SEGMENT_MS)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_START -> startRecordingLoop()
            ACTION_STOP -> stopRecordingLoop()
            ACTION_PAUSE -> pauseRecordingLoop()
            ACTION_RESUME -> resumeRecordingLoop()
            ACTION_TOGGLE -> if (running) stopRecordingLoop() else startRecordingLoop()
            ACTION_REFRESH_NOTIFICATION -> if (running) updateNotification()
            ACTION_LOCK_INCIDENT -> lockCurrentOrLatestSegment()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopRecordingLoop()
        super.onDestroy()
    }

    private fun startRecordingLoop() {
        if (running) return
        if (!hasCameraPermission()) {
            DashcamStatusStore.onWarning("Camera permission is required to record.", this)
            return
        }

        ensureNotificationChannel()
        loadExistingSegments()
        running = true
        paused = false
        startForeground(NOTIFICATION_ID, buildNotification())
        DashcamStatusStore.notifyRecordingStarted(this)
        DashcamStatusStore.resumeRecording(this)
        bindCameraAndStartRecording()
        mainHandler.postDelayed(ticker, 1000)
        mainHandler.postDelayed(segmentRollover, SEGMENT_MS)
    }

    private fun stopRecordingLoop() {
        if (!running && currentRecording == null) return
        running = false
        paused = false
        pendingServiceStop = true
        rollingToNextSegment = false
        mainHandler.removeCallbacks(ticker)
        mainHandler.removeCallbacks(segmentRollover)

        // If a recording is active, wait for Finalize so the partial segment
        // (even < 5 minutes) is flushed to disk before stopping the service.
        if (currentRecording != null) {
            currentRecording?.stop()
            return
        }

        finalizeServiceStop()
    }

    private fun finalizeServiceStop() {
        currentRecording = null
        cameraProvider?.unbindAll()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        DashcamStatusStore.onStopped(this)
        pendingServiceStop = false
    }

    private fun bindCameraAndStartRecording() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                cameraProvider = future.get()
                val recorder = Recorder.Builder()
                    .setQualitySelector(
                        QualitySelector.from(
                            Quality.FHD,
                            FallbackStrategyHolder.selector
                        )
                    )
                    .build()
                videoCapture = VideoCapture.withOutput(recorder)

                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    this,
                    if (DashcamStatusStore.isFrontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else if (DashcamStatusStore.isFrontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA,
                    videoCapture
                )
                startNewSegment()
            } catch (t: Throwable) {
                DashcamStatusStore.onWarning("Unable to start camera: ${t.message ?: "unknown"}", this)
                stopRecordingLoop()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun startNewSegment() {
        val capture = videoCapture ?: run {
            DashcamStatusStore.onWarning("Camera pipeline not ready.", this)
            return
        }

        val name = "dashcam_${timestamp()}.mp4"
        currentSegmentName = name
        currentSegmentLocked = false

        val pending: PendingRecording = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            currentSegmentFile = null
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/Dashcam")
            }
            val mediaStoreOptions = MediaStoreOutputOptions.Builder(
                contentResolver,
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            ).setContentValues(values).build()
            capture.output.prepareRecording(this, mediaStoreOptions)
        } else {
            val outputDir = getLegacyOutputDirectory()
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }
            val file = File(outputDir, name)
            currentSegmentFile = file
            val fileOptions = FileOutputOptions.Builder(file).build()
            capture.output.prepareRecording(this, fileOptions)
        }

        if (hasAudioPermission()) {
            currentRecording = pending.withAudioEnabled()
                .start(ContextCompat.getMainExecutor(this)) { event ->
                    when (event) {
                        is VideoRecordEvent.Finalize -> onSegmentFinalized(event)
                    }
                }
            return
        }

        currentRecording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
            when (event) {
                is VideoRecordEvent.Finalize -> onSegmentFinalized(event)
            }
        }
    }

    private fun onSegmentFinalized(event: VideoRecordEvent.Finalize) {
        val file = currentSegmentFile
        val uri = event.outputResults.outputUri.takeIf { it != Uri.EMPTY }
        val segmentName = currentSegmentName.ifBlank { file?.name ?: "dashcam_unknown.mp4" }
        currentSegmentFile = null
        currentSegmentName = ""
        currentRecording = null

        if (event.hasError()) {
            DashcamStatusStore.onWarning("Clip save error: ${event.cause?.message ?: event.error}", this)
        }

        val sizeMb = when {
            uri != null -> getMediaStoreSizeMb(uri)
            file != null && file.exists() -> (file.length() / (1024 * 1024)).toInt().coerceAtLeast(1)
            else -> 0
        }

        if ((uri != null && sizeMb > 0) || (file != null && file.exists() && sizeMb > 0)) {
            segments.add(
                SegmentMeta(
                    uri = uri,
                    file = file,
                    name = segmentName,
                    sizeMb = sizeMb,
                    locked = currentSegmentLocked,
                )
            )
            usedMb = segments.sumOf { it.sizeMb }
            pruneUnlockedSegmentsIfNeeded()
            DashcamStatusStore.onSegmentFinalized(segmentName, usedMb, currentSegmentLocked, this)
        } else if (!event.hasError()) {
            DashcamStatusStore.onWarning("Clip non trovata dopo finalize.", this)
        }

        if (pendingServiceStop) {
            finalizeServiceStop()
            return
        }

        if (running && rollingToNextSegment) {
            rollingToNextSegment = false
            startNewSegment()
        }
    }

    private fun rollToNextSegment() {
        if (!running || currentRecording == null || rollingToNextSegment) {
            return
        }
        rollingToNextSegment = true
        currentRecording?.stop()
    }

    private fun pauseRecordingLoop() {
        if (!running || paused || currentRecording == null) return
        try {
            currentRecording?.pause()
            paused = true
            DashcamStatusStore.pauseRecording(this)
            updateNotification()
        } catch (t: Throwable) {
            DashcamStatusStore.onWarning("Pause error: ${t.message ?: "unknown"}", this)
        }
    }

    private fun resumeRecordingLoop() {
        if (!running || !paused || currentRecording == null) return
        try {
            currentRecording?.resume()
            paused = false
            DashcamStatusStore.resumeRecording(this)
            updateNotification()
        } catch (t: Throwable) {
            DashcamStatusStore.onWarning("Resume error: ${t.message ?: "unknown"}", this)
        }
    }

    private fun lockCurrentOrLatestSegment() {
        if (paused) {
            DashcamStatusStore.onWarning("Resume recording before locking the current segment.", this)
            return
        }
        if (currentRecording != null) {
            currentSegmentLocked = true
            DashcamStatusStore.onWarning("Incident marker will lock the current segment.", this)
            return
        }

        val latest = segments.lastOrNull() ?: run {
            DashcamStatusStore.onWarning("No segment available to lock yet.", this)
            return
        }
        latest.locked = true
        DashcamStatusStore.onWarning("Locked ${latest.name}.", this)
    }

    private fun pruneUnlockedSegmentsIfNeeded() {
        var freeMb = DashcamStatusStore.getFreeStorageMb(this)
        if (freeMb >= 500) {
            return
        }

        val iterator = segments.iterator()
        while (freeMb < 500 && iterator.hasNext()) {
            val segment = iterator.next()
            if (segment.locked) {
                continue
            }
            val deleted = when {
                segment.uri != null -> contentResolver.delete(segment.uri, null, null) > 0
                segment.file != null -> {
                    val file = segment.file
                    file?.delete() == true
                }
                else -> false
            }
            if (deleted) {
                usedMb -= segment.sizeMb
                freeMb += segment.sizeMb
                iterator.remove()
            }
        }

        freeMb = DashcamStatusStore.getFreeStorageMb(this)
        if (freeMb < 500) {
            DashcamStatusStore.onWarning("Storage full and all remaining clips are locked.", this)
        }
    }

    private fun loadExistingSegments() {
        segments.clear()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.Video.Media.RELATIVE_PATH,
                MediaStore.MediaColumns.DATE_MODIFIED,
            )
            val selection = "${MediaStore.Video.Media.RELATIVE_PATH} = ?"
            val args = arrayOf("${Environment.DIRECTORY_MOVIES}/Dashcam/")
            val sort = "${MediaStore.MediaColumns.DATE_MODIFIED} ASC"
            contentResolver.query(collection, projection, selection, args, sort)?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idIdx)
                    val name = cursor.getString(nameIdx) ?: "dashcam_unknown.mp4"
                    val sizeMb = ((cursor.getLong(sizeIdx)) / (1024 * 1024)).toInt().coerceAtLeast(1)
                    val uri = ContentUris.withAppendedId(collection, id)
                    segments.add(SegmentMeta(uri = uri, file = null, name = name, sizeMb = sizeMb, locked = false))
                }
            }
        } else {
            val dir = getLegacyOutputDirectory()
            if (dir.exists()) {
                dir.listFiles { f -> f.isFile && f.extension.lowercase(Locale.US) == "mp4" }
                    ?.sortedBy { it.lastModified() }
                    ?.forEach { file ->
                        val sizeMb = (file.length() / (1024 * 1024)).toInt().coerceAtLeast(1)
                        segments.add(
                            SegmentMeta(
                                uri = null,
                                file = file,
                                name = file.name,
                                sizeMb = sizeMb,
                                locked = false,
                            )
                        )
                    }
            }
        }
        usedMb = segments.sumOf { it.sizeMb }
    }

    private fun getLegacyOutputDirectory(): File {
        return File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "Dashcam")
    }

    private fun getMediaStoreSizeMb(uri: Uri): Int {
        val projection = arrayOf(MediaStore.MediaColumns.SIZE)
        var sizeBytes = 0L
        contentResolver.query(uri, projection, null, null, null)?.use { cursor: Cursor ->
            if (cursor.moveToFirst()) {
                val sizeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
                if (sizeIdx >= 0) {
                    sizeBytes = cursor.getLong(sizeIdx)
                }
            }
        }
        return (sizeBytes / (1024 * 1024)).toInt().coerceAtLeast(1)
    }

    private fun timestamp(): String {
        return SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    }

    private fun hasCameraPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasAudioPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun ensureNotificationChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Dashcam Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows dashcam recording state"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val hours = elapsedSeconds / 3600
        val mins = (elapsedSeconds % 3600) / 60
        val secs = elapsedSeconds % 60
        val speedKmh = DashcamStatusStore.getLiveSpeedKmh()
        val subtitle = String.format(
            Locale.US,
            "%02d:%02d:%02d • %.1f km/h",
            hours,
            mins,
            secs,
            speedKmh
        )

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            4201,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val pauseResumeIntent = Intent(this, DashcamForegroundService::class.java).apply {
            action = if (paused) ACTION_RESUME else ACTION_PAUSE
        }
        val pauseResumePendingIntent = PendingIntent.getService(
            this,
            4202,
            pauseResumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(this, DashcamForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            4203,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val pauseResumeLabel = if (paused) "Resume" else "Pause"
        val pauseResumeIcon =
            if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (paused) "Dashcam paused" else "Dashcam")
            .setContentText(subtitle)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openAppPendingIntent)
            .addAction(pauseResumeIcon, pauseResumeLabel, pauseResumePendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .build()
    }

    companion object {
        const val ACTION_START = "dashcam.action.START"
        const val ACTION_STOP = "dashcam.action.STOP"
        const val ACTION_PAUSE = "dashcam.action.PAUSE"
        const val ACTION_RESUME = "dashcam.action.RESUME"
        const val ACTION_TOGGLE = "dashcam.action.TOGGLE"
        const val ACTION_REFRESH_NOTIFICATION = "dashcam.action.REFRESH_NOTIFICATION"
        const val ACTION_LOCK_INCIDENT = "dashcam.action.LOCK"

        private const val CHANNEL_ID = "dashcam_recording"
        private const val NOTIFICATION_ID = 7001
        private const val SEGMENT_MS = 5 * 60 * 1000L
    }

    private object FallbackStrategyHolder {
        val selector = FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
    }
}
