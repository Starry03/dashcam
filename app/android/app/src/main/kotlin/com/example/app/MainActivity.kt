package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
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
                    "lockIncident" -> {
                        DashcamStatusStore.lockIncident(this)
                        result.success(null)
                    }
                    "setCameraLens" -> {
                        val isFront = call.argument<Boolean>("isFrontCamera") ?: false
                        DashcamStatusStore.setCameraLens(isFront, this)
                        result.success(null)
                    }
                    "openVideoFolder" -> {
                        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video/*")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        try {
                            startActivity(viewIntent)
                            result.success(null)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(Intent.ACTION_PICK, android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(fallbackIntent)
                                result.success(null)
                            } catch(e2: Exception) {
                                result.error("ERROR", "Nessuna app compatibile", null)
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
        val needed = listOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        ).filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), 1001)
        }
    }
}
