package com.example.ai_blind_assistant

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener as AndroidRecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener as VoskRecognitionListener
import org.vosk.android.SpeechService as VoskSpeechService
import org.vosk.android.StorageService

/**
 * Bounded, phone-local speech recognition for assistant commands.
 *
 * Android's dedicated API 31+ recognizer is preferred when the device image
 * provides one. Vendor images that omit it automatically use the Vosk English
 * model packaged inside this APK. The ordinary [SpeechRecognizer] is never
 * created because Android permits that implementation to use a remote service.
 * Transcript text remains in memory and is never logged by this handler.
 */
class OnDeviceSpeechRecognizerHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler, AndroidRecognitionListener, VoskRecognitionListener {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var androidRecognizer: SpeechRecognizer? = null
    private var voskModel: Model? = null
    private var voskRecognizer: Recognizer? = null
    private var voskSpeechService: VoskSpeechService? = null
    private var activeProvider: RecognitionProvider? = null
    private var sessionMode: SessionMode? = null

    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingSessionMode: SessionMode? = null
    private var modelLoadGeneration = 0
    private var modelLoading = false
    private var disposed = false

    private var pendingStopResult: MethodChannel.Result? = null
    private var completedPayload: Map<String, Any?>? = null
    private var completedError: RecognitionError? = null
    private var stopTimeout: Runnable? = null
    private val voskSegments = mutableListOf<String>()
    private var voskPartialTranscript = ""
    private var awaitingHandsFreeCommand = false
    private var handsFreeWakeTimeout: Runnable? = null
    private var partialWakeTimeout: Runnable? = null
    private var lastHandledHandsFreeTranscript: String? = null

    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
    private var isCallInterrupted = false

    private val audioFocusChangeListener = android.media.AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            android.media.AudioManager.AUDIOFOCUS_LOSS,
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                isCallInterrupted = true
                pauseHandsFree()
                mainHandler.post {
                    channel.invokeMethod("onInterruptionStarted", null)
                }
            }
            android.media.AudioManager.AUDIOFOCUS_GAIN -> {
                if (isCallInterrupted) {
                    isCallInterrupted = false
                    resumeHandsFree(acceptNextCommand = false)
                    mainHandler.post {
                        channel.invokeMethod("onInterruptionEnded", null)
                    }
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability" -> result.success(availabilityPayload())
            "startListening" -> startListening(call, result)
            "stopListening" -> stopListening(result)
            "cancelListening" -> {
                cancelAndReset()
                result.success(null)
            }
            "startHandsFree" -> startHandsFree(call, result)
            "pauseHandsFree" -> {
                pauseHandsFree()
                result.success(null)
            }
            "resumeHandsFree" -> {
                resumeHandsFree(call.argument<Boolean>("acceptNextCommand") == true)
                result.success(null)
            }
            "stopHandsFree" -> {
                stopHandsFree()
                result.success(null)
            }
            "setRecognitionProfile" -> {
                val profile = call.argument<String>("profile") ?: "normal"
                setRecognitionProfile(profile)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        disposed = true
        modelLoadGeneration += 1
        pendingStartResult?.error(
            "recognizer_disposed",
            "Speech recognition was stopped.",
            null,
        )
        pendingStartResult = null
        pendingSessionMode = null
        pendingStopResult?.error(
            "recognizer_disposed",
            "Speech recognition was stopped.",
            null,
        )
        pendingStopResult = null
        cancelAndReset()
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
        try {
            voskModel?.close()
        } catch (_: Exception) {
            // Model is already being released.
        }
        voskModel = null
    }

    private fun availabilityPayload(): Map<String, Any?> {
        val androidAvailable = dedicatedAndroidRecognizerAvailable()
        val bundledAvailable = bundledModelAvailable()
        val available = androidAvailable || bundledAvailable
        val reason = if (available) {
            null
        } else {
            "This build does not contain a working offline speech recognizer."
        }
        return mapOf(
            "available" to available,
            "platformVersion" to Build.VERSION.SDK_INT,
            "reason" to reason,
            "provider" to when {
                androidAvailable -> RecognitionProvider.ANDROID.wireName
                bundledAvailable -> RecognitionProvider.VOSK.wireName
                else -> null
            },
            "dedicatedAndroidAvailable" to androidAvailable,
            "bundledOfflineAvailable" to bundledAvailable,
        )
    }

    private fun dedicatedAndroidRecognizerAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    private fun bundledModelAvailable(): Boolean = try {
        context.assets.open("$VOSK_ASSET_PATH/uuid").use { it.read() != -1 }
    } catch (_: IOException) {
        false
    }

    private fun startListening(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("recognizer_disposed", "Speech recognition is unavailable.", null)
            return
        }
        if (isBusy()) {
            result.error(
                "recognizer_busy",
                "An offline speech recognition session is already active.",
                null,
            )
            return
        }

        completedPayload = null
        completedError = null
        voskSegments.clear()
        voskPartialTranscript = ""
        val locale = call.argument<String>("locale")
            ?.takeIf { it.isNotBlank() }
            ?: Locale.getDefault().toLanguageTag()

        if (dedicatedAndroidRecognizerAvailable() && startAndroidListening(locale, result)) {
            return
        }
        if (!bundledModelAvailable()) {
            result.error(
                "on_device_unavailable",
                "This build does not contain a working offline speech recognizer.",
                null,
            )
            return
        }
        startVoskListening(locale, result, SessionMode.PUSH_TO_TALK)
    }

    /** Returns true once the method-channel result has been completed. */
    private fun startAndroidListening(locale: String, result: MethodChannel.Result): Boolean {
        return try {
            val created = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            androidRecognizer = created
            activeProvider = RecognitionProvider.ANDROID
            created.setRecognitionListener(this)
            created.startListening(recognitionIntent(locale))
            result.success(true)
            true
        } catch (_: Exception) {
            // A few vendor builds claim support but fail when the dedicated
            // recognizer is created. Release it and use the bundled model.
            destroyAndroidRecognizer()
            activeProvider = null
            false
        }
    }

    private fun startVoskListening(
        locale: String,
        result: MethodChannel.Result,
        requestedMode: SessionMode,
    ) {
        val loadedModel = voskModel
        if (loadedModel != null) {
            createVoskSession(loadedModel, result, requestedMode)
            return
        }
        if (modelLoading) {
            result.error("recognizer_busy", "The offline speech model is preparing.", null)
            return
        }

        modelLoading = true
        pendingStartResult = result
        pendingSessionMode = requestedMode
        val generation = ++modelLoadGeneration
        StorageService.unpack(
            context,
            VOSK_ASSET_PATH,
            VOSK_STORAGE_PATH,
            { loaded ->
                modelLoading = false
                if (disposed || generation != modelLoadGeneration) {
                    try {
                        loaded.close()
                    } catch (_: Exception) {
                        // Model is already being released.
                    }
                    return@unpack
                }
                voskModel = loaded
                val pending = pendingStartResult
                val mode = pendingSessionMode
                pendingStartResult = null
                pendingSessionMode = null
                if (pending != null && mode != null) {
                    mainHandler.post {
                        createVoskSession(loaded, pending, mode)
                    }
                }
            },
            { error ->
                modelLoading = false
                if (disposed || generation != modelLoadGeneration) return@unpack
                val pending = pendingStartResult
                pendingStartResult = null
                pendingSessionMode = null
                mainHandler.post {
                    pending?.error(
                        "bundled_model_load_failed",
                        "The bundled offline speech model could not be prepared.",
                        mapOf("errorType" to error.javaClass.simpleName),
                    )
                }
            },
        )
    }

    private fun createVoskSession(
        model: Model,
        result: MethodChannel.Result,
        requestedMode: SessionMode,
    ) {
        try {
            val createdRecognizer = Recognizer(model, VOSK_SAMPLE_RATE)
            // Zero keeps Vosk's result contract as {"text":"..."}. A
            // positive value moves the transcript into alternatives[], which
            // previously made every final wake result look blank to this
            // handler even while microphone capture was healthy.
            createdRecognizer.setMaxAlternatives(VisionAiVoskContract.maxAlternatives)
            createdRecognizer.setWords(false)
            createdRecognizer.setPartialWords(false)
            val createdService = VoskSpeechService(createdRecognizer, VOSK_SAMPLE_RATE)
            voskRecognizer = createdRecognizer
            voskSpeechService = createdService
            activeProvider = RecognitionProvider.VOSK
            sessionMode = requestedMode
            val started = if (requestedMode == SessionMode.HANDS_FREE) {
                try {
                    val pm = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                    if (wakeLock == null) {
                        wakeLock = pm?.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "AIBlindAssistant:HandsFreeWakeLock")
                    }
                    if (wakeLock?.isHeld == false) {
                        wakeLock?.acquire(2 * 60 * 60 * 1000L)
                    }
                } catch (_: Exception) {}
                createdService.startListening(this)
            } else {
                createdService.startListening(this, MAX_SESSION_MS)
            }
            if (!started) {
                throw IllegalStateException("Vosk recognition thread did not start.")
            }
            try {
                val recorderField = createdService.javaClass.getDeclaredField("recorder")
                recorderField.isAccessible = true
                val audioRecord = recorderField.get(createdService) as? android.media.AudioRecord
                if (audioRecord != null) {
                    val sessionId = audioRecord.audioSessionId
                    var aecActive = false
                    var nsActive = false
                    var agcActive = false
                    if (android.media.audiofx.AcousticEchoCanceler.isAvailable()) {
                        val aec = android.media.audiofx.AcousticEchoCanceler.create(sessionId)
                        aec?.enabled = true
                        aecActive = aec?.enabled == true
                    }
                    if (android.media.audiofx.NoiseSuppressor.isAvailable()) {
                        val ns = android.media.audiofx.NoiseSuppressor.create(sessionId)
                        ns?.enabled = true
                        nsActive = ns?.enabled == true
                    }
                    if (android.media.audiofx.AutomaticGainControl.isAvailable()) {
                        val agc = android.media.audiofx.AutomaticGainControl.create(sessionId)
                        agc?.enabled = true
                        agcActive = agc?.enabled == true
                    }
                    android.util.Log.d("VisionAudio", "AudioRecord initialized. session=$sessionId AEC=$aecActive NS=$nsActive AGC=$agcActive profile=$currentProfileName")
                }
            } catch (_: Exception) {}
            result.success(true)
        } catch (error: Exception) {
            destroyVoskSession(cancel = true)
            activeProvider = null
            result.error(
                "recognizer_start_failed",
                "Bundled offline speech recognition could not start.",
                mapOf("errorType" to error.javaClass.simpleName),
            )
        }
    }

    private fun startHandsFree(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("recognizer_disposed", "Speech recognition is unavailable.", null)
            return
        }
        if (sessionMode == SessionMode.HANDS_FREE && voskSpeechService != null) {
            resumeHandsFree()
            result.success(true)
            return
        }
        if (isBusy()) {
            result.error(
                "recognizer_busy",
                "Another offline speech recognition session is active.",
                null,
            )
            return
        }
        if (!bundledModelAvailable()) {
            result.error(
                "on_device_unavailable",
                "This build does not contain the hands-free offline model.",
                null,
            )
            return
        }
        completedPayload = null
        completedError = null
        awaitingHandsFreeCommand = false
        lastHandledHandsFreeTranscript = null
        val locale = call.argument<String>("locale")
            ?.takeIf { it.isNotBlank() }
            ?: Locale.getDefault().toLanguageTag()
        startVoskListening(locale, result, SessionMode.HANDS_FREE)
    }

    private var pauseWatchdog: Runnable? = null

    private fun pauseHandsFree() {
        if (sessionMode == SessionMode.HANDS_FREE) {
            try {
                voskSpeechService?.setPause(true)
            } catch (_: Exception) {}
            cancelPauseWatchdog()
            val watchdog = Runnable {
                if (sessionMode == SessionMode.HANDS_FREE && activeProvider == RecognitionProvider.VOSK) {
                    android.util.Log.d("VisionAudio", "HandsFree pause watchdog triggered - auto-resuming listening")
                    resumeHandsFree(acceptNextCommand = false)
                }
            }
            pauseWatchdog = watchdog
            mainHandler.postDelayed(watchdog, 15000L)
        }
    }

    private fun cancelPauseWatchdog() {
        pauseWatchdog?.let(mainHandler::removeCallbacks)
        pauseWatchdog = null
    }

    private fun resumeHandsFree(acceptNextCommand: Boolean = false) {
        cancelPauseWatchdog()
        if (sessionMode == SessionMode.HANDS_FREE) {
            awaitingHandsFreeCommand = acceptNextCommand
            lastHandledHandsFreeTranscript = null
            if (acceptNextCommand) {
                scheduleHandsFreeWakeTimeout()
            } else {
                cancelHandsFreeWakeTimeout()
            }
            // Discard any buffered wake phrase or TTS echo before accepting
            // the next user utterance.
            try {
                voskRecognizer?.reset()
            } catch (_: Exception) {}
            try {
                voskSpeechService?.setPause(false)
            } catch (_: Exception) {}
        }
    }

    private var currentProfileName: String = "normal"

    private fun setRecognitionProfile(profile: String) {
        currentProfileName = profile
        android.util.Log.d("VisionAudio", "Recognition profile set to: $profile")
        val model = voskModel ?: return
        if (sessionMode == SessionMode.HANDS_FREE && activeProvider == RecognitionProvider.VOSK && voskSpeechService != null) {
            mainHandler.post {
                val newRecognizer = Recognizer(model, VOSK_SAMPLE_RATE)
                newRecognizer.setMaxAlternatives(VisionAiVoskContract.maxAlternatives)
                newRecognizer.setWords(false)
                newRecognizer.setPartialWords(false)
                voskRecognizer = newRecognizer
                val service = voskSpeechService
                if (service != null) {
                    val recField = service.javaClass.getDeclaredField("recognizer")
                    recField.isAccessible = true
                    recField.set(service, newRecognizer)
                }
                lastHandledHandsFreeTranscript = null
                voskPartialTranscript = ""
                voskRecognizer?.reset()
            } catch (e: Exception) {
                android.util.Log.w("VisionAudio", "Could not hot-swap recognizer grammar: $e")
            }
        }
    }

    private fun stopHandsFree() {
        if (sessionMode != SessionMode.HANDS_FREE && pendingSessionMode != SessionMode.HANDS_FREE) {
            return
        }
        cancelPauseWatchdog()
        cancelHandsFreeWakeTimeout()
        cancelPartialWakeTimeout()
        awaitingHandsFreeCommand = false
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
        cancelAndReset()
    }

    private fun stopListening(result: MethodChannel.Result) {
        completedPayload?.let { payload ->
            completedPayload = null
            result.success(payload)
            return
        }
        completedError?.let { error ->
            completedError = null
            result.error(error.code, error.message, error.details())
            return
        }
        if (pendingStopResult != null) {
            result.error("stop_in_progress", "Speech recognition is already stopping.", null)
            return
        }

        when (activeProvider) {
            RecognitionProvider.ANDROID -> stopAndroidListening(result)
            RecognitionProvider.VOSK -> stopVoskListening(result)
            null -> result.error(
                "not_listening",
                "No speech recognition session is active.",
                null,
            )
        }
    }

    private fun stopAndroidListening(result: MethodChannel.Result) {
        val active = androidRecognizer
        if (active == null) {
            result.error("not_listening", "No speech recognition session is active.", null)
            return
        }
        pendingStopResult = result
        try {
            active.stopListening()
            scheduleStopTimeout()
        } catch (_: Exception) {
            finishWithError(
                RecognitionError(
                    "recognizer_stop_failed",
                    "Offline speech recognition could not stop cleanly.",
                    SpeechRecognizer.ERROR_CLIENT,
                ),
            )
        }
    }

    private fun stopVoskListening(result: MethodChannel.Result) {
        val active = voskSpeechService
        if (active == null) {
            result.error("not_listening", "No speech recognition session is active.", null)
            return
        }
        pendingStopResult = result
        try {
            if (!active.stop()) {
                finishVoskTranscript()
            } else {
                scheduleStopTimeout()
            }
        } catch (_: Exception) {
            finishWithError(
                RecognitionError(
                    "recognizer_stop_failed",
                    "Bundled offline speech recognition could not stop cleanly.",
                    SpeechRecognizer.ERROR_CLIENT,
                ),
            )
        }
    }

    private fun recognitionIntent(locale: String): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }

    private fun scheduleStopTimeout() {
        stopTimeout?.let(mainHandler::removeCallbacks)
        val timeout = Runnable {
            if (pendingStopResult != null) {
                if (activeProvider == RecognitionProvider.VOSK) {
                    finishVoskTranscript()
                } else {
                    finishWithError(
                        RecognitionError(
                            "recognition_timeout",
                            "Offline speech recognition timed out.",
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                        ),
                    )
                }
            }
        }
        stopTimeout = timeout
        mainHandler.postDelayed(timeout, STOP_TIMEOUT_MS)
    }

    private fun finishWithPayload(payload: Map<String, Any?>) {
        cancelStopTimeout()
        destroyActiveSession()
        val pending = pendingStopResult
        pendingStopResult = null
        if (pending != null) {
            pending.success(payload)
        } else {
            completedPayload = payload
        }
    }

    private fun finishWithError(error: RecognitionError) {
        cancelStopTimeout()
        destroyActiveSession()
        val pending = pendingStopResult
        pendingStopResult = null
        if (pending != null) {
            pending.error(error.code, error.message, error.details())
        } else {
            completedError = error
        }
    }

    private fun finishVoskTranscript(finalJson: String? = null) {
        transcriptFromJson(finalJson, "text")
            .takeIf { it.isNotBlank() }
            ?.let(::addVoskSegment)
        val transcript = voskSegments.joinToString(" ").trim().ifEmpty {
            voskPartialTranscript.trim()
        }
        if (transcript.isEmpty()) {
            finishWithError(
                RecognitionError(
                    "no_speech",
                    "No speech was recognized. Please try again.",
                    SpeechRecognizer.ERROR_NO_MATCH,
                ),
            )
            return
        }
        finishWithPayload(
            mapOf(
                "transcript" to transcript,
                "confidence" to null,
                "provider" to RecognitionProvider.VOSK.wireName,
            ),
        )
    }

    private fun cancelAndReset() {
        modelLoadGeneration += 1
        modelLoading = false
        pendingStartResult?.error(
            "recognition_cancelled",
            "Speech recognition was cancelled.",
            null,
        )
        pendingStartResult = null
        pendingSessionMode = null
        cancelPauseWatchdog()
        cancelHandsFreeWakeTimeout()
        cancelPartialWakeTimeout()
        awaitingHandsFreeCommand = false
        cancelStopTimeout()
        destroyActiveSession(cancel = true)
        completedPayload = null
        completedError = null
        voskSegments.clear()
        voskPartialTranscript = ""
    }

    private fun destroyActiveSession(cancel: Boolean = false) {
        when (activeProvider) {
            RecognitionProvider.ANDROID -> {
                if (cancel) {
                    try {
                        androidRecognizer?.cancel()
                    } catch (_: Exception) {
                        // Destroy still runs.
                    }
                }
                destroyAndroidRecognizer()
            }
            RecognitionProvider.VOSK -> destroyVoskSession(cancel)
            null -> {
                destroyAndroidRecognizer()
                destroyVoskSession(cancel)
            }
        }
        activeProvider = null
        sessionMode = null
    }

    private fun destroyAndroidRecognizer() {
        try {
            androidRecognizer?.destroy()
        } catch (_: Exception) {
            // Resource is already being released.
        }
        androidRecognizer = null
    }

    private fun destroyVoskSession(cancel: Boolean) {
        val service = voskSpeechService
        if (service != null) {
            if (cancel) {
                try {
                    service.cancel()
                } catch (_: Exception) {
                    // Shutdown still runs.
                }
            }
            try {
                service.shutdown()
            } catch (_: Exception) {
                // AudioRecord is already released.
            }
        }
        voskSpeechService = null
        try {
            voskRecognizer?.close()
        } catch (_: Exception) {
            // Recognizer is already being released.
        }
        voskRecognizer = null
    }

    private fun cancelStopTimeout() {
        stopTimeout?.let(mainHandler::removeCallbacks)
        stopTimeout = null
    }

    private fun cancelHandsFreeWakeTimeout() {
        handsFreeWakeTimeout?.let(mainHandler::removeCallbacks)
        handsFreeWakeTimeout = null
    }

    private fun isBusy(): Boolean =
        activeProvider != null || modelLoading || pendingStartResult != null || pendingStopResult != null

    // Android dedicated recognizer callbacks.
    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() = Unit

    override fun onError(error: Int) {
        if (activeProvider == RecognitionProvider.ANDROID) {
            finishWithError(errorDetails(error))
        }
    }

    override fun onResults(results: Bundle?) {
        if (activeProvider != RecognitionProvider.ANDROID) return
        val matches = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            .orEmpty()
        val transcript = matches.firstOrNull { it.isNotBlank() }?.trim().orEmpty()
        if (transcript.isEmpty()) {
            finishWithError(
                RecognitionError(
                    "no_speech",
                    "No speech was recognized. Please try again.",
                    SpeechRecognizer.ERROR_NO_MATCH,
                ),
            )
            return
        }
        val confidence = results
            ?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            ?.firstOrNull()
            ?.takeIf { it >= 0f }
        finishWithPayload(
            mapOf(
                "transcript" to transcript,
                "confidence" to confidence?.toDouble(),
                "provider" to RecognitionProvider.ANDROID.wireName,
            ),
        )
    }

    override fun onPartialResults(partialResults: Bundle?) = Unit

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    // Bundled Vosk recognizer callbacks. Vosk dispatches these on the main loop.
    override fun onPartialResult(hypothesis: String) {
        if (activeProvider != RecognitionProvider.VOSK) return
        voskPartialTranscript = transcriptFromJson(hypothesis, "partial")
        if (sessionMode == SessionMode.HANDS_FREE) {
            if (!awaitingHandsFreeCommand) {
                handlePartialHandsFreeTranscript(voskPartialTranscript)
            }
        }
    }

    override fun onResult(hypothesis: String) {
        if (activeProvider != RecognitionProvider.VOSK) return
        val transcript = transcriptFromJson(hypothesis, "text")
        if (sessionMode == SessionMode.HANDS_FREE) {
            cancelPartialWakeTimeout()
            handleHandsFreeTranscript(transcript)
        } else {
            transcript.takeIf { it.isNotBlank() }?.let(::addVoskSegment)
        }
        voskPartialTranscript = ""
    }

    override fun onFinalResult(hypothesis: String) {
        if (activeProvider == RecognitionProvider.VOSK) {
            if (sessionMode == SessionMode.HANDS_FREE) {
                cancelPartialWakeTimeout()
                handleHandsFreeTranscript(transcriptFromJson(hypothesis, "text"))
            } else {
                finishVoskTranscript(hypothesis)
            }
        }
    }

    override fun onError(exception: Exception) {
        if (activeProvider == RecognitionProvider.VOSK) {
            if (sessionMode == SessionMode.HANDS_FREE) {
                channel.invokeMethod(
                    "onHandsFreeError",
                    mapOf("errorType" to exception.javaClass.simpleName),
                )
                destroyActiveSession(cancel = true)
                return
            }
            finishWithError(
                RecognitionError(
                    "audio_error",
                    "The microphone audio could not be processed offline.",
                    SpeechRecognizer.ERROR_AUDIO,
                    exception.javaClass.simpleName,
                ),
            )
        }
    }

    override fun onTimeout() {
        if (activeProvider == RecognitionProvider.VOSK && sessionMode != SessionMode.HANDS_FREE) {
            finishVoskTranscript()
        }
    }



    private fun handleHandsFreeTranscript(rawTranscript: String) {
        val transcript = rawTranscript.trim()
        if (transcript.isEmpty() || sessionMode != SessionMode.HANDS_FREE) return
        val normalized = transcript.lowercase(Locale.US).replace(WHITESPACE_REGEX, " ")
        if (normalized.isEmpty() || normalized == "[unk]" || normalized == "unk") return
        if (normalized == lastHandledHandsFreeTranscript) return

        if (isDirectInterruption(normalized)) {
            cancelHandsFreeWakeTimeout()
            cancelPartialWakeTimeout()
            awaitingHandsFreeCommand = false
            voskRecognizer?.reset()
            lastHandledHandsFreeTranscript = normalized
            channel.invokeMethod(
                "onHandsFreeCommand",
                mapOf("transcript" to normalized),
            )
            return
        }

        if (awaitingHandsFreeCommand) {
            // Vosk can deliver the same utterance in both onResult and
            // onFinalResult. Never mistake the just-handled wake phrase for
            // the user's follow-up command.
            val repeatedWake = VisionAiWakePhrase.match(normalized)
            if (repeatedWake != null && repeatedWake.command.isEmpty()) {
                lastHandledHandsFreeTranscript = normalized
                return
            }
            cancelHandsFreeWakeTimeout()
            awaitingHandsFreeCommand = false
            pauseHandsFree()
            lastHandledHandsFreeTranscript = normalized
            channel.invokeMethod(
                "onHandsFreeCommand",
                mapOf(
                    "transcript" to repeatedWake
                        ?.command
                        ?.takeIf { it.isNotEmpty() }
                        .orEmpty()
                        .ifEmpty { transcript },
                ),
            )
            return
        }

        val wakeMatch = VisionAiWakePhrase.match(normalized)
        if (wakeMatch != null) {
            val command = wakeMatch.command
            pauseHandsFree()
            lastHandledHandsFreeTranscript = normalized
            if (command.isNotEmpty()) {
                channel.invokeMethod(
                    "onHandsFreeCommand",
                    mapOf("transcript" to command),
                )
                return
            }

            awaitingHandsFreeCommand = true
            scheduleHandsFreeWakeTimeout()
            channel.invokeMethod("onHandsFreeWake", null)
            return
        }



        // Ambient noise / [unk] - keep hands-free active and listening
    }

    /**
     * Wake immediately when the offline decoder has already produced the
     * complete standalone wake phrase as a partial hypothesis. This avoids
     * waiting forever on devices that do not emit a timely final result.
     * Combined "Hey Vision AI, do ..." requests still wait for the final
     * hypothesis so their full command is not cut off.
     */
    private fun handlePartialHandsFreeTranscript(rawTranscript: String) {
        val transcript = rawTranscript.trim()
        if (transcript.isEmpty() || sessionMode != SessionMode.HANDS_FREE) return
        val normalized = transcript.lowercase(Locale.US).replace(WHITESPACE_REGEX, " ")
        if (normalized == lastHandledHandsFreeTranscript) return

        // Wake immediately when the offline decoder has already produced the
        // complete standalone wake phrase as a partial hypothesis.
        val wakeMatch = VisionAiWakePhrase.match(normalized)
        if (wakeMatch != null && wakeMatch.command.isEmpty()) {
            cancelPartialWakeTimeout()
            cancelHandsFreeWakeTimeout()
            awaitingHandsFreeCommand = true
            lastHandledHandsFreeTranscript = normalized
            scheduleHandsFreeWakeTimeout()
            channel.invokeMethod("onHandsFreeWake", null)
            return
        }

        val timeout = Runnable {
            if (sessionMode == SessionMode.HANDS_FREE && !awaitingHandsFreeCommand) {
                lastHandledHandsFreeTranscript = normalized
                pauseHandsFree()
                awaitingHandsFreeCommand = true
                scheduleHandsFreeWakeTimeout()
                channel.invokeMethod("onHandsFreeWake", null)
            }
        }
        partialWakeTimeout = timeout
        mainHandler.postDelayed(timeout, PARTIAL_WAKE_SETTLE_MS)
    }

    private fun scheduleHandsFreeWakeTimeout() {
        cancelHandsFreeWakeTimeout()
        val timeout = Runnable {
            if (sessionMode == SessionMode.HANDS_FREE && awaitingHandsFreeCommand) {
                awaitingHandsFreeCommand = false
                pauseHandsFree()
                channel.invokeMethod("onHandsFreeTimeout", null)
            }
        }
        handsFreeWakeTimeout = timeout
        mainHandler.postDelayed(timeout, HANDS_FREE_COMMAND_TIMEOUT_MS)
    }

    private fun cancelPartialWakeTimeout() {
        partialWakeTimeout?.let(mainHandler::removeCallbacks)
        partialWakeTimeout = null
    }

    private fun addVoskSegment(segment: String) {
        val normalized = segment.trim()
        if (normalized.isNotEmpty() && voskSegments.lastOrNull() != normalized) {
            voskSegments += normalized
        }
    }

    private fun transcriptFromJson(json: String?, field: String): String {
        if (json.isNullOrBlank()) return ""
        return try {
            val payload = JSONObject(json)
            payload.optString(field, "").trim().ifEmpty {
                // Defensive compatibility if a future Vosk configuration
                // intentionally enables n-best alternatives again.
                payload
                    .optJSONArray("alternatives")
                    ?.optJSONObject(0)
                    ?.optString("text", "")
                    ?.trim()
                    .orEmpty()
            }
        } catch (_: Exception) {
            ""
        }
    }

    private fun errorDetails(error: Int): RecognitionError = when (error) {
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        SpeechRecognizer.ERROR_NO_MATCH,
        -> RecognitionError("no_speech", "No speech was recognized. Please try again.", error)
        SpeechRecognizer.ERROR_AUDIO ->
            RecognitionError("audio_error", "The microphone audio could not be processed.", error)
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
            RecognitionError("permission_denied", "Microphone permission is required.", error)
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
            RecognitionError("language_not_supported", "This speech language is not supported.", error)
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            RecognitionError(
                "language_unavailable",
                "The offline speech language pack is not installed.",
                error,
            )
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
            RecognitionError("recognizer_busy", "The speech recognizer is busy.", error)
        else -> RecognitionError(
            "recognition_failed",
            "On-device speech recognition failed. Please try again.",
            error,
        )
    }

    private data class RecognitionError(
        val code: String,
        val message: String,
        val platformCode: Int,
        val nativeErrorType: String? = null,
    ) {
        fun details(): Map<String, Any?> = mapOf(
            "errorCode" to platformCode,
            "nativeErrorType" to nativeErrorType,
        )
    }

    private enum class RecognitionProvider(val wireName: String) {
        ANDROID("android_dedicated"),
        VOSK("bundled_vosk"),
    }

    private enum class SessionMode {
        PUSH_TO_TALK,
        HANDS_FREE,
    }

    private companion object {
        const val STOP_TIMEOUT_MS = 8_000L
        const val PARTIAL_WAKE_SETTLE_MS = 650L
        const val HANDS_FREE_COMMAND_TIMEOUT_MS = 60_000L
        const val MAX_SESSION_MS = 30_000
        const val VOSK_SAMPLE_RATE = 16_000f
        const val VOSK_ASSET_PATH = "model-en-us"
        const val VOSK_STORAGE_PATH = "offline-speech"
        val WHITESPACE_REGEX = Regex("\\s+")
}
