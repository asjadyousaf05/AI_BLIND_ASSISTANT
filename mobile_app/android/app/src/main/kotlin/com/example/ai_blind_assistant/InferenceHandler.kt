package com.example.ai_blind_assistant

import android.content.res.AssetManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Runs model loading, preprocessing and inference on one background thread. */
class InferenceHandler(private val assetManager: AssetManager) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val inferencePending = AtomicBoolean(false)

    private var interpreter: Interpreter? = null
    private var inputShape = intArrayOf()
    private var outputShape = intArrayOf()
    private var inputType = DataType.FLOAT32
    private var outputType = DataType.FLOAT32
    private var inputScale = 0.0f
    private var inputZeroPoint = 0
    private var outputScale = 0.0f
    private var outputZeroPoint = 0
    private var inputBuffer: ByteBuffer? = null
    private var outputBuffer: ByteBuffer? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val modelAsset = call.argument<String>("modelAsset").orEmpty()
                executor.execute { loadModel(modelAsset, result) }
            }

            "runInference" -> {
                if (!inferencePending.compareAndSet(false, true)) {
                    result.error("INFERENCE_BUSY", "The previous frame is still processing", null)
                    return
                }
                val planes = parsePlanes(call.argument<List<Map<String, Any?>>>("planes"))
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val rotation = call.argument<Int>("rotation") ?: 0
                val mirror = call.argument<Boolean>("mirrorHorizontally") ?: false
                executor.execute {
                    try {
                        runInference(planes, width, height, rotation, mirror, result)
                    } finally {
                        inferencePending.set(false)
                    }
                }
            }

            "dispose" -> executor.execute {
                releaseInterpreter()
                success(result, null)
            }

            else -> result.notImplemented()
        }
    }

    fun close() {
        executor.execute { releaseInterpreter() }
        executor.shutdown()
    }

    private fun loadModel(assetPath: String, result: MethodChannel.Result) {
        try {
            require(assetPath.isNotBlank()) { "The model asset path is empty" }
            releaseInterpreter()

            val candidate = Interpreter(
                loadModelFile(assetPath),
                Interpreter.Options().apply { numThreads = 2 },
            )
            require(candidate.inputTensorCount == 1 && candidate.outputTensorCount == 1) {
                "Expected exactly one model input and one output"
            }

            val inputTensor = candidate.getInputTensor(0)
            val outputTensor = candidate.getOutputTensor(0)
            val candidateInputShape = inputTensor.shape()
            val candidateOutputShape = outputTensor.shape()
            require(validInputShape(candidateInputShape)) {
                "Unsupported input shape ${candidateInputShape.contentToString()}"
            }
            require(validOutputShape(candidateOutputShape)) {
                "Unsupported output shape ${candidateOutputShape.contentToString()}"
            }
            require(inputTensor.dataType() in supportedTypes) {
                "Unsupported input type ${inputTensor.dataType()}"
            }
            require(outputTensor.dataType() in supportedTypes) {
                "Unsupported output type ${outputTensor.dataType()}"
            }

            interpreter = candidate
            inputShape = candidateInputShape
            outputShape = candidateOutputShape
            inputType = inputTensor.dataType()
            outputType = outputTensor.dataType()
            inputScale = inputTensor.quantizationParams().scale
            inputZeroPoint = inputTensor.quantizationParams().zeroPoint
            outputScale = outputTensor.quantizationParams().scale
            outputZeroPoint = outputTensor.quantizationParams().zeroPoint
            inputBuffer = directBuffer(inputTensor.numBytes())
            outputBuffer = directBuffer(outputTensor.numBytes())

            // A real interpreter invocation validates operators and prepares
            // kernels before the first live frame reaches the app.
            val warmupStart = System.nanoTime()
            candidate.run(inputBuffer!!.apply { clear() }, outputBuffer!!.apply { clear() })
            val warmupMillis = (System.nanoTime() - warmupStart) / 1_000_000

            success(
                result,
                mapOf(
                    "loaded" to true,
                    "inputShape" to inputShape.toList(),
                    "outputShape" to outputShape.toList(),
                    "inputType" to inputType.toString(),
                    "outputType" to outputType.toString(),
                    "inputScale" to inputScale.toDouble(),
                    "inputZeroPoint" to inputZeroPoint,
                    "outputScale" to outputScale.toDouble(),
                    "outputZeroPoint" to outputZeroPoint,
                    "warmupTimeMs" to warmupMillis,
                    "threads" to 2,
                    "delegate" to "CPU",
                ),
            )
        } catch (error: Throwable) {
            releaseInterpreter()
            failure(result, "MODEL_LOAD_FAILED", safeMessage(error))
        }
    }

    private fun runInference(
        planes: List<PlaneData>,
        width: Int,
        height: Int,
        rotation: Int,
        mirror: Boolean,
        result: MethodChannel.Result,
    ) {
        val activeInterpreter = interpreter
        if (activeInterpreter == null) {
            failure(result, "MODEL_NOT_LOADED", "Load the detection model before inference")
            return
        }

        try {
            require(width > 0 && height > 0) { "Invalid camera frame dimensions" }
            require(rotation in setOf(0, 90, 180, 270)) { "Unsupported camera rotation $rotation" }
            require(planes.size >= 3) { "Expected Y, U and V camera planes" }

            val preprocessing = preprocessImage(planes, width, height, rotation, mirror)
            val output = outputBuffer ?: error("Output buffer is unavailable")
            output.clear()

            val start = System.nanoTime()
            activeInterpreter.run(inputBuffer!!.apply { rewind() }, output)
            val inferenceMillis = (System.nanoTime() - start) / 1_000_000
            val outputValues = readOutput(output)

            success(
                result,
                mapOf(
                    "output" to outputValues,
                    "shape" to outputShape.toList(),
                    "inferenceTimeMs" to inferenceMillis,
                    "inputWidth" to preprocessing.inputWidth,
                    "inputHeight" to preprocessing.inputHeight,
                    "previewWidth" to preprocessing.previewWidth,
                    "previewHeight" to preprocessing.previewHeight,
                    "letterboxScale" to preprocessing.scale,
                    "letterboxPaddingX" to preprocessing.paddingX,
                    "letterboxPaddingY" to preprocessing.paddingY,
                ),
            )
        } catch (error: Throwable) {
            failure(result, "INFERENCE_FAILED", safeMessage(error))
        }
    }

    /**
     * Converts stride-aware Android YUV_420_888 directly into the model tensor.
     * The upright image is resized with aspect ratio preserved and padded with
     * Ultralytics' standard RGB 114 letterbox colour.
     */
    private fun preprocessImage(
        planes: List<PlaneData>,
        sourceWidth: Int,
        sourceHeight: Int,
        rotation: Int,
        mirror: Boolean,
    ): ImageTransform {
        val nchw = inputShape[1] == 3
        val modelHeight = if (nchw) inputShape[2] else inputShape[1]
        val modelWidth = if (nchw) inputShape[3] else inputShape[2]
        val previewWidth = if (rotation == 90 || rotation == 270) sourceHeight else sourceWidth
        val previewHeight = if (rotation == 90 || rotation == 270) sourceWidth else sourceHeight
        val scale = min(
            modelWidth.toDouble() / previewWidth,
            modelHeight.toDouble() / previewHeight,
        )
        val scaledWidth = previewWidth * scale
        val scaledHeight = previewHeight * scale
        val paddingX = (modelWidth - scaledWidth) / 2.0
        val paddingY = (modelHeight - scaledHeight) / 2.0

        val tensor = inputBuffer ?: error("Input buffer is unavailable")
        tensor.clear()
        for (y in 0 until modelHeight) {
            for (x in 0 until modelWidth) {
                var red = 114
                var green = 114
                var blue = 114
                if (
                    x + 0.5 >= paddingX && x + 0.5 < paddingX + scaledWidth &&
                    y + 0.5 >= paddingY && y + 0.5 < paddingY + scaledHeight
                ) {
                    var previewX = ((x + 0.5 - paddingX) / scale - 0.5).roundToInt()
                    val previewY = ((y + 0.5 - paddingY) / scale - 0.5).roundToInt()
                    previewX = previewX.coerceIn(0, previewWidth - 1)
                    val uprightY = previewY.coerceIn(0, previewHeight - 1)
                    if (mirror) previewX = previewWidth - 1 - previewX
                    val (sourceX, sourceY) = inverseRotate(
                        previewX,
                        uprightY,
                        sourceWidth,
                        sourceHeight,
                        rotation,
                    )
                    val rgb = sampleYuv(planes, sourceX, sourceY)
                    red = rgb.first
                    green = rgb.second
                    blue = rgb.third
                }
                writeInput(tensor, nchw, modelWidth, modelHeight, x, y, 0, red)
                writeInput(tensor, nchw, modelWidth, modelHeight, x, y, 1, green)
                writeInput(tensor, nchw, modelWidth, modelHeight, x, y, 2, blue)
            }
        }
        tensor.rewind()
        return ImageTransform(
            modelWidth,
            modelHeight,
            previewWidth,
            previewHeight,
            scale,
            paddingX,
            paddingY,
        )
    }

    private fun inverseRotate(
        x: Int,
        y: Int,
        sourceWidth: Int,
        sourceHeight: Int,
        rotation: Int,
    ): Pair<Int, Int> = when (rotation) {
        0 -> Pair(x, y)
        90 -> Pair(y, sourceHeight - 1 - x)
        180 -> Pair(sourceWidth - 1 - x, sourceHeight - 1 - y)
        270 -> Pair(sourceWidth - 1 - y, x)
        else -> error("Unsupported rotation")
    }

    private fun sampleYuv(planes: List<PlaneData>, x: Int, y: Int): Rgb {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val yValue = unsigned(yPlane.bytes[y * yPlane.rowStride + x * yPlane.pixelStride])
        val chromaX = x / 2
        val chromaY = y / 2
        val uValue = unsigned(uPlane.bytes[chromaY * uPlane.rowStride + chromaX * uPlane.pixelStride])
        val vValue = unsigned(vPlane.bytes[chromaY * vPlane.rowStride + chromaX * vPlane.pixelStride])

        val u = uValue - 128.0
        val v = vValue - 128.0
        val red = (yValue + 1.402 * v).roundToInt().coerceIn(0, 255)
        val green = (yValue - 0.344136 * u - 0.714136 * v).roundToInt().coerceIn(0, 255)
        val blue = (yValue + 1.772 * u).roundToInt().coerceIn(0, 255)
        return Rgb(red, green, blue)
    }

    private fun writeInput(
        buffer: ByteBuffer,
        nchw: Boolean,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        channel: Int,
        channelValue: Int,
    ) {
        val elementIndex = if (nchw) {
            channel * width * height + y * width + x
        } else {
            (y * width + x) * 3 + channel
        }
        val normalized = channelValue / 255.0f
        when (inputType) {
            DataType.FLOAT32 -> buffer.putFloat(elementIndex * Float.SIZE_BYTES, normalized)
            DataType.UINT8 -> {
                val quantized = quantize(normalized, inputScale, inputZeroPoint).coerceIn(0, 255)
                buffer.put(elementIndex, quantized.toByte())
            }

            DataType.INT8 -> {
                val quantized = quantize(normalized, inputScale, inputZeroPoint).coerceIn(-128, 127)
                buffer.put(elementIndex, quantized.toByte())
            }

            else -> error("Unsupported input type $inputType")
        }
    }

    private fun readOutput(buffer: ByteBuffer): FloatArray {
        buffer.rewind()
        val count = outputShape.fold(1) { product, dimension -> product * dimension }
        return when (outputType) {
            DataType.FLOAT32 -> FloatArray(count).also { buffer.asFloatBuffer().get(it) }
            DataType.UINT8 -> FloatArray(count) {
                ((unsigned(buffer.get()) - outputZeroPoint) * outputScale)
            }

            DataType.INT8 -> FloatArray(count) {
                ((buffer.get().toInt() - outputZeroPoint) * outputScale)
            }

            else -> error("Unsupported output type $outputType")
        }
    }

    private fun parsePlanes(rawPlanes: List<Map<String, Any?>>?): List<PlaneData> {
        return rawPlanes.orEmpty().map { plane ->
            PlaneData(
                bytes = plane["bytes"] as? ByteArray ?: ByteArray(0),
                rowStride = plane["bytesPerRow"] as? Int ?: 0,
                pixelStride = max(plane["bytesPerPixel"] as? Int ?: 1, 1),
            )
        }
    }

    private fun validInputShape(shape: IntArray): Boolean {
        if (shape.size != 4 || shape[0] != 1) return false
        return (shape[1] == 3 && shape[2] > 0 && shape[3] > 0) ||
            (shape[1] > 0 && shape[2] > 0 && shape[3] == 3)
    }

    private fun validOutputShape(shape: IntArray): Boolean {
        return shape.size == 3 && shape[0] == 1 && shape.drop(1).all { it > 0 }
    }

    private fun loadModelFile(assetPath: String): MappedByteBuffer {
        assetManager.openFd("flutter_assets/$assetPath").use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).use { input ->
                return input.channel.map(
                    FileChannel.MapMode.READ_ONLY,
                    descriptor.startOffset,
                    descriptor.declaredLength,
                )
            }
        }
    }

    private fun releaseInterpreter() {
        interpreter?.close()
        interpreter = null
        inputShape = intArrayOf()
        outputShape = intArrayOf()
        inputBuffer = null
        outputBuffer = null
    }

    private fun directBuffer(size: Int): ByteBuffer =
        ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())

    private fun quantize(value: Float, scale: Float, zeroPoint: Int): Int {
        require(scale > 0) { "Quantized tensor has no valid scale" }
        return (value / scale).roundToInt() + zeroPoint
    }

    private fun unsigned(value: Byte): Int = value.toInt() and 0xff

    private fun safeMessage(error: Throwable): String =
        error.message?.take(180) ?: error::class.java.simpleName

    private fun success(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun failure(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    private data class PlaneData(
        val bytes: ByteArray,
        val rowStride: Int,
        val pixelStride: Int,
    )

    private data class ImageTransform(
        val inputWidth: Int,
        val inputHeight: Int,
        val previewWidth: Int,
        val previewHeight: Int,
        val scale: Double,
        val paddingX: Double,
        val paddingY: Double,
    )

    private data class Rgb(val first: Int, val second: Int, val third: Int)

    companion object {
        private val supportedTypes = setOf(DataType.FLOAT32, DataType.UINT8, DataType.INT8)
    }
}
