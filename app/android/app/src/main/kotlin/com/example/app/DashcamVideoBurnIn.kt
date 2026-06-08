package com.example.app

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object DashcamVideoBurnIn {
    data class Sample(
        val timestampMs: Long,
        val speedKmh: Double,
    )

    data class Result(
        val processed: Boolean,
        val sizeMb: Int,
    )

    private const val FONT_NAME = "Roboto"

    // Resolved once; null means the FFmpeg AAR is not on the classpath.
    private val ffmpegKitClass: Class<*>? by lazy {
        try { Class.forName("com.arthenica.ffmpegkit.FFmpegKit") } catch (_: ClassNotFoundException) { null }
    }
    private val ffmpegKitConfigClass: Class<*>? by lazy {
        try { Class.forName("com.arthenica.ffmpegkit.FFmpegKitConfig") } catch (_: ClassNotFoundException) { null }
    }
    private val returnCodeClass: Class<*>? by lazy {
        try { Class.forName("com.arthenica.ffmpegkit.ReturnCode") } catch (_: ClassNotFoundException) { null }
    }

    private val ffmpegAvailable: Boolean get() =
        ffmpegKitClass != null && ffmpegKitConfigClass != null && returnCodeClass != null

    fun processSegment(
        context: Context,
        sourceFile: File?,
        sourceUri: Uri?,
        samples: List<Sample>,
    ): Result {
        val fallbackSizeMb = when {
            sourceFile != null && sourceFile.exists() -> fileSizeMb(sourceFile.length())
            sourceUri != null -> uriSizeMb(context, sourceUri)
            else -> 0
        }

        if (!ffmpegAvailable || samples.isEmpty() || (sourceFile == null && sourceUri == null)) {
            return Result(processed = false, sizeMb = fallbackSizeMb)
        }

        // FFmpegKitConfig.setFontDirectoryList(context, listOf("/system/fonts"), emptyMap())
        ffmpegKitConfigClass!!
            .getMethod("setFontDirectoryList", Context::class.java, List::class.java, Map::class.java)
            .invoke(null, context, listOf("/system/fonts"), emptyMap<String, String>())

        val workDir = File(context.cacheDir, "dashcam-burnin").apply { mkdirs() }
        val stamp = System.currentTimeMillis()
        val inputFile = File(workDir, "input_$stamp.mp4")
        val outputFile = File(workDir, "output_$stamp.mp4")
        val subtitlesFile = File(workDir, "overlay_$stamp.ass")

        try {
            if (sourceFile != null) {
                sourceFile.copyTo(inputFile, overwrite = true)
            } else if (sourceUri != null) {
                context.contentResolver.openInputStream(sourceUri)?.use { input ->
                    FileOutputStream(inputFile).use { output -> input.copyTo(output) }
                } ?: return Result(processed = false, sizeMb = fallbackSizeMb)
            }

            subtitlesFile.writeText(buildAss(samples))

            val command = buildCommand(inputFile, outputFile, subtitlesFile)

            // val session = FFmpegKit.execute(command)
            val session = ffmpegKitClass!!
                .getMethod("execute", String::class.java)
                .invoke(null, command)

            // val returnCode = session.returnCode
            val returnCode = session!!.javaClass.getMethod("getReturnCode").invoke(session)

            // if (!ReturnCode.isSuccess(returnCode) || !outputFile.exists())
            val isSuccess = returnCodeClass!!
                .getMethod("isSuccess", returnCodeClass)
                .invoke(null, returnCode) as Boolean

            if (!isSuccess || !outputFile.exists()) {
                return Result(processed = false, sizeMb = fallbackSizeMb)
            }

            when {
                sourceFile != null -> outputFile.copyTo(sourceFile, overwrite = true)
                sourceUri != null -> {
                    context.contentResolver.openOutputStream(sourceUri, "w")?.use { out ->
                        outputFile.inputStream().use { it.copyTo(out) }
                    } ?: return Result(processed = false, sizeMb = fallbackSizeMb)
                }
            }

            val processedSizeMb = when {
                sourceFile != null -> fileSizeMb(sourceFile.length())
                sourceUri != null -> uriSizeMb(context, sourceUri)
                else -> fallbackSizeMb
            }
            return Result(processed = true, sizeMb = processedSizeMb)
        } catch (_: Throwable) {
            return Result(processed = false, sizeMb = fallbackSizeMb)
        } finally {
            inputFile.delete()
            outputFile.delete()
            subtitlesFile.delete()
        }
    }

    private fun buildCommand(inputFile: File, outputFile: File, subtitlesFile: File): String {
        val subtitlesFilter = "subtitles=${quotePath(subtitlesFile.absolutePath)}"
        return buildString {
            append("-y -i ")
            append(quotePath(inputFile.absolutePath))
            append(" -map 0:v:0 -map 0:a? -vf \"")
            append(subtitlesFilter)
            append("\" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a copy -movflags +faststart ")
            append(quotePath(outputFile.absolutePath))
        }
    }

    private fun buildAss(samples: List<Sample>): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
        val content = StringBuilder()
        content.appendLine("[Script Info]")
        content.appendLine("ScriptType: v4.00+")
        content.appendLine("PlayResX: 1920")
        content.appendLine("PlayResY: 1080")
        content.appendLine("WrapStyle: 2")
        content.appendLine("ScaledBorderAndShadow: yes")
        content.appendLine()
        content.appendLine("[V4+ Styles]")
        content.appendLine(
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
        )
        content.appendLine(
            "Style: Default,$FONT_NAME,36,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,2,3,3,32,40,40,1",
        )
        content.appendLine()
        content.appendLine("[Events]")
        content.appendLine(
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
        )

        samples.forEachIndexed { index, sample ->
            val startSeconds = index.toDouble()
            val endSeconds = startSeconds + 1.0
            val text = buildString {
                append("{\\fs28\\c&HCCCCCC&}")
                append(formatter.format(Date(sample.timestampMs)))
                append("\\N{\\fs46\\c&HFFFFFF&}")
                append(String.format(Locale.US, "%.1f km/h", sample.speedKmh))
            }
            content.appendLine(
                "Dialogue: 0,${formatAssTime(startSeconds)},${formatAssTime(endSeconds)},Default,,0,0,0,,$text",
            )
        }

        return content.toString()
    }

    private fun formatAssTime(seconds: Double): String {
        val totalCentiseconds = (seconds * 100).toInt().coerceAtLeast(0)
        val hours = totalCentiseconds / 360000
        val minutes = (totalCentiseconds % 360000) / 6000
        val secs = (totalCentiseconds % 6000) / 100
        val centiseconds = totalCentiseconds % 100
        return String.format(Locale.US, "%d:%02d:%02d.%02d", hours, minutes, secs, centiseconds)
    }

    private fun quotePath(path: String): String = "'${path.replace("'", "\\'")}'"

    private fun fileSizeMb(bytes: Long): Int = (bytes / (1024 * 1024)).toInt().coerceAtLeast(1)

    private fun uriSizeMb(context: Context, uri: Uri): Int {
        val projection = arrayOf(android.provider.MediaStore.MediaColumns.SIZE)
        var sizeBytes = 0L
        context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val sizeIdx = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.SIZE)
                if (sizeIdx >= 0) sizeBytes = cursor.getLong(sizeIdx)
            }
        }
        return fileSizeMb(sizeBytes)
    }
}
