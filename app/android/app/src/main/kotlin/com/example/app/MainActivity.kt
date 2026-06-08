package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var eventChannel: EventChannel
    private var statusSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dashcam/control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        ensurePermissions()
                        DashcamStatusStore.startRecording(this)
                        result.success(null)
                    }
                    "stopRecording" -> {
                        DashcamStatusStore.stopRecording(this)
                        result.success(null)
                    }
                    "pauseRecording" -> {
                        val intent = Intent(this, DashcamForegroundService::class.java).apply {
                            action = DashcamForegroundService.ACTION_PAUSE
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "resumeRecording" -> {
                        val intent = Intent(this, DashcamForegroundService::class.java).apply {
                            action = DashcamForegroundService.ACTION_RESUME
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "lockIncident" -> {
                        DashcamStatusStore.lockIncident(this)
                        result.success(null)
                    }
                    "setCameraLens" -> {
                        val isFront = call.argument<Boolean>("isFrontCamera") ?: false
                        DashcamStatusStore.setCameraLens(isFront, this)
                        result.success(null)
                    }
                    "refreshStatus" -> {
                        DashcamStatusStore.emitCurrent(this)
                        result.success(null)
                    }
                    "updateLiveStats" -> {
                        val speedKmh = call.argument<Double>("speedKmh") ?: 0.0
                        DashcamStatusStore.updateLiveSpeed(speedKmh)
                        result.success(null)
                    }
                    "openVideoFolder" -> {
                        try {
                            val intent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_GALLERY)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            try {
                                val fallback = Intent(Intent.ACTION_VIEW)
                                fallback.type = "video/*"
                                fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(fallback)
                                result.success(null)
                            } catch(e2: Exception) {
                                result.error("ERROR", "No compatible app found", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dashcam/status")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusSink = events
                DashcamStatusStore.onStatus = { map ->
                    runOnUiThread { statusSink?.success(map) }
                }
                DashcamStatusStore.emitCurrent(this@MainActivity)
            }

            override fun onCancel(arguments: Any?) {
                statusSink = null
                DashcamStatusStore.onStatus = null
            }
        })
    }

    private fun ensurePermissions() {
        val needed = mutableListOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val missing = needed.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1001)
        }
    }
}
