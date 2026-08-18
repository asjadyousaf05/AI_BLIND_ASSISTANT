package com.example.ai_blind_assistant

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bounded, user-initiated microphone capture for assistant push-to-talk.
 *
 * Output is restricted to the app cache directory. The Dart caller deletes the
 * clip immediately after upload; cancellation and native failures delete it
 * here as a second line of defence. No audio bytes or file paths are logged.
 */
class AssistantAudioRecorderHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var recording = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> startRecording(call, result)
            "stopRecording" -> stopRecording(result)
            "cancelRecording" -> cancelRecording(result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        stopInternal(deleteOutput = true)
    }

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        if (recording || recorder != null) {
            result.error("recording_in_progress", "A recording is already in progress.", null)
            return
        }

        val requestedPath = call.argument<String>("path")
        val file = requestedPath?.let(::File)
        if (file == null || !isInsideCache(file)) {
            result.error("invalid_output_path", "The recording output path is invalid.", null)
            return
        }

        try {
            file.parentFile?.mkdirs()
            if (file.exists()) file.delete()

            outputFile = file
            val created = createRecorder()
            recorder = created
            created.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioChannels(1)
                setAudioSamplingRate(16_000)
                setAudioEncodingBitRate(64_000)
                setOutputFile(file.absolutePath)
                setMaxDuration(MAX_DURATION_MS)
                setMaxFileSize(MAX_FILE_SIZE_BYTES)
                setOnInfoListener { _, what, _ ->
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED ||
                        what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED
                    ) {
                        stopInternal(deleteOutput = false)
                    }
                }
                setOnErrorListener { _, _, _ -> stopInternal(deleteOutput = true) }
                prepare()
                start()
            }

            recording = true
            result.success(true)
        } catch (_: Exception) {
            stopInternal(deleteOutput = true)
            result.error("recording_start_failed", "The microphone could not start recording.", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (recorder == null && !recording) {
            // A duration or size limit may already have stopped the recorder.
            result.success(null)
            return
        }
        val stoppedCleanly = stopInternal(deleteOutput = false)
        if (stoppedCleanly) {
            result.success(null)
        } else {
            result.error("recording_stop_failed", "The recording could not be completed.", null)
        }
    }

    private fun cancelRecording(result: MethodChannel.Result) {
        stopInternal(deleteOutput = true)
        result.success(null)
    }

    private fun stopInternal(deleteOutput: Boolean): Boolean {
        val activeRecorder = recorder
        recorder = null
        recording = false
        var stoppedCleanly = true
        if (activeRecorder != null) {
            try {
                activeRecorder.stop()
            } catch (_: RuntimeException) {
                stoppedCleanly = false
            } finally {
                try {
                    activeRecorder.reset()
                } catch (_: Exception) {
                    // Release still runs.
                }
                activeRecorder.release()
            }
        }

        if (deleteOutput || !stoppedCleanly) {
            outputFile?.delete()
            outputFile = null
        }
        return stoppedCleanly
    }

    private fun isInsideCache(file: File): Boolean {
        return try {
            val cachePath = context.cacheDir.canonicalFile.toPath()
            file.canonicalFile.toPath().startsWith(cachePath)
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun createRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            MediaRecorder()
        }
    }

    private companion object {
        const val MAX_DURATION_MS = 30_000
        const val MAX_FILE_SIZE_BYTES = 4L * 1024L * 1024L
    }
}
