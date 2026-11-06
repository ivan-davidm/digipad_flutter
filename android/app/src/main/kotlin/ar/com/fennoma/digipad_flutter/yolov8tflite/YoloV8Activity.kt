package ar.com.digipad

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.util.AttributeSet
import android.util.Log
import android.os.Environment
import android.view.ScaleGestureDetector
import android.widget.FrameLayout
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import ar.com.digipad.yolov8tflite.BoundingBox
import ar.com.digipad.yolov8tflite.Constants
import ar.com.digipad.yolov8tflite.Detector
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean


class YoloV8View @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val previewView: PreviewView
    private val detector: Detector
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    private var cameraSelector: CameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
    private var isFrontCamera: Boolean = false
    private var lifecycleOwner: LifecycleOwner? = null
    private val isDisposed = AtomicBoolean(false)
    private val isCameraBound = AtomicBoolean(false)
    private val isBinding = AtomicBoolean(false)
    private var pendingZoomRatio: Float? = null

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) {
            super.onStart(owner)
            if (!isDisposed.get()) {
                Log.d("YoloV8View", "Lifecycle: ON_START. Reloading detector.")
                detector.setup()
            }
        }
        override fun onResume(owner: LifecycleOwner) {
            super.onResume(owner)
            if (!isDisposed.get()) {
                Log.d("YoloV8View", "Lifecycle: ON_RESUME. Attempting to bind camera use cases.")
                bindCameraUseCases()
            }
        }
        override fun onPause(owner: LifecycleOwner) {
            super.onPause(owner)
            if (!isDisposed.get()) {
                Log.d("YoloV8View", "Lifecycle: ON_PAUSE. Unbinding camera use cases.")
                unbindCamera()
            }
        }
        override fun onStop(owner: LifecycleOwner) {
            super.onStop(owner)
            if (!isDisposed.get()) {
                Log.d("YoloV8View", "Lifecycle: ON_STOP. Clearing detector to free memory.")
                detector.clear()
            }
        }
    }

    fun detectImageSync(bitmap: Bitmap): List<BoundingBox> = detector.detectSync(bitmap)

    init {
        Log.d("YoloV8View", "Initializing new YoloV8View instance. Hash: ${this.hashCode()}")
        setBackgroundColor(Color.BLACK)

        previewView = PreviewView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        addView(previewView)

        // Pinch-to-zoom via CameraX linear zoom.
        val scaleDetector = ScaleGestureDetector(context,
            object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                override fun onScale(d: ScaleGestureDetector): Boolean {
                    val current = camera?.cameraInfo?.zoomState?.value?.linearZoom ?: 0.5f
                    val next = (current + (d.scaleFactor - 1f) * 0.5f).coerceIn(0f, 1f)
                    camera?.cameraControl?.setLinearZoom(next)
                    return true
                }
            })
        previewView.setOnTouchListener { _, event -> scaleDetector.onTouchEvent(event); true }

        // Detection happens post-capture only (detectFromFile). No live overlay needed.
        detector = Detector(context, Constants.MODEL_PATH, Constants.LABELS_PATH,
            object : Detector.DetectorListener {
                override fun onEmptyDetect() {}
                override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {}
            })
        detector.setup()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        Log.d("YoloV8View", "onAttachedToWindow")
        // Keep a handle to THIS future and reuse it below. Calling
        // ProcessCameraProvider.getInstance(context) a second time inside the listener
        // re-enters CameraX's init path on the main thread; on a device with no camera
        // (e.g. the Totem) CameraX's internal shutdown needs to run a task on the main
        // thread via runOnMainSync, which can't happen because the main thread is stuck
        // in that second .get() — a real deadlock, only broken by CameraX's own ~30s
        // internal timeout ("Timeout to wait main thread execution"), well past Android's
        // 5s ANR threshold. Reusing the same future's already-resolved result avoids it.
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            if (isDisposed.get()) {
                Log.d("YoloV8View", "View disposed during camera initialization, skipping.")
                return@addListener
            }
            try {
                cameraProvider = providerFuture.get(3, TimeUnit.SECONDS)
                findActivity()?.let { activity ->
                    if (activity is LifecycleOwner) {
                        lifecycleOwner = activity
                        activity.lifecycle.addObserver(lifecycleObserver)
                        Log.d("YoloV8View", "Lifecycle observer attached.")
                    }
                }
                // Explicit bind if onResume already fired before this async callback completed.
                val owner = lifecycleOwner
                if (!isDisposed.get() && !isCameraBound.get() &&
                    owner != null && owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                    bindCameraUseCases()
                }
            } catch (e: Exception) {
                Log.e("YoloV8View", "Error initializing camera provider", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindCameraUseCases() {
        if (!isBinding.compareAndSet(false, true)) {
            Log.d("YoloV8View", "Binding already in progress, skipping.")
            return
        }
        try {
            if (isCameraBound.get() || isDisposed.get()) {
                Log.d("YoloV8View", "bindCameraUseCases skipped: already bound or disposed.")
                return
            }
            val provider = cameraProvider ?: run {
                Log.e("YoloV8View", "CameraProvider is null, cannot bind.")
                return
            }
            val activity = findActivity() as? LifecycleOwner ?: run {
                Log.e("YoloV8View", "LifecycleOwner not found, cannot bind.")
                return
            }
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                    != PackageManager.PERMISSION_GRANTED) {
                Log.e("YoloV8View", "Camera permission not granted, cannot bind.")
                return
            }

            // Fall back to front camera on devices with no rear camera (e.g. front-only tablets).
            val selector = if (!provider.hasCamera(cameraSelector)) {
                Log.w("YoloV8View", "Requested camera unavailable, falling back to front camera.")
                isFrontCamera = true
                cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
                cameraSelector
            } else {
                cameraSelector
            }

            val preview = Preview.Builder()
                .setTargetRotation(display.rotation)
                .build().apply {
                setSurfaceProvider(previewView.surfaceProvider)
            }
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setJpegQuality(97)
                .setTargetRotation(display.rotation)
                .build()

            provider.unbindAll()
            camera = provider.bindToLifecycle(activity, selector, preview, imageCapture)
            isCameraBound.set(true)
            Log.d("YoloV8View", "Camera use cases bound successfully.")
            pendingZoomRatio?.let { ratio ->
                try {
                    val zs = camera?.cameraInfo?.zoomState?.value
                    val clamped = if (zs != null) ratio.coerceIn(zs.minZoomRatio, zs.maxZoomRatio) else ratio
                    camera?.cameraControl?.setZoomRatio(clamped)
                } catch (_: Exception) {}
                pendingZoomRatio = null
            }
        } catch (e: Exception) {
            Log.e("YoloV8View", "Failed to bind camera use cases", e)
        } finally {
            isBinding.set(false)
        }
    }

    private fun unbindCamera() {
        try {
            cameraProvider?.unbindAll()
            isCameraBound.set(false)
            camera = null
            Log.d("YoloV8View", "Camera unbound successfully.")
        } catch (e: Exception) {
            Log.e("YoloV8View", "Error unbinding camera", e)
        }
    }

    fun dispose() {
        if (!isDisposed.compareAndSet(false, true)) {
            Log.d("YoloV8View", "Already disposed, skipping.")
            return
        }
        Log.d("YoloV8View", "Starting disposal...")
        try {
            lifecycleOwner?.lifecycle?.removeObserver(lifecycleObserver)
            lifecycleOwner = null
            imageCapture = null
            cameraProvider?.unbindAll()
            isCameraBound.set(false)
            camera = null
            detector.clear()
            Log.d("YoloV8View", "Detector cleared.")
            cameraExecutor.shutdown()
            try {
                if (!cameraExecutor.awaitTermination(2000, TimeUnit.MILLISECONDS)) {
                    cameraExecutor.shutdownNow()
                    Log.w("YoloV8View", "Executor did not terminate in time, forcing shutdown.")
                }
            } catch (e: InterruptedException) {
                cameraExecutor.shutdownNow()
                Thread.currentThread().interrupt()
            }
            Log.d("YoloV8View", "Camera executor shut down.")
            cameraProvider = null
            Log.d("YoloV8View", "Disposal completed successfully.")
        } catch (e: Exception) {
            Log.e("YoloV8View", "Error during disposal", e)
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        Log.d("YoloV8View", "onDetachedFromWindow called.")
        dispose()
    }

    private fun findActivity(): Activity? {
        var currentContext = context
        while (currentContext is ContextWrapper) {
            if (currentContext is Activity) return currentContext
            currentContext = currentContext.baseContext
        }
        return null
    }

    // region: Flutter control API

    fun setTorch(enabled: Boolean) {
        try { camera?.cameraControl?.enableTorch(enabled) } catch (_: Exception) {}
    }

    fun switchCamera(front: Boolean) {
        isFrontCamera = front
        cameraSelector = if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
        unbindCamera()
        bindCameraUseCases()
    }

    fun setZoomRatio(ratio: Float) {
        try {
            val cam = camera
            if (cam == null) { pendingZoomRatio = ratio; return }
            val zoomState = cam.cameraInfo.zoomState.value
            val clamped = if (zoomState != null) {
                ratio.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
            } else ratio
            cam.cameraControl.setZoomRatio(clamped)
        } catch (_: Exception) {}
    }

    fun capturePhoto(callback: (path: String?, error: String?) -> Unit) {
        val capture = imageCapture ?: run { callback(null, "ImageCapture not initialized"); return }
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss").format(Date())
        val outputDir = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: context.filesDir
        val photoFile = File(outputDir, "IMG_${timeStamp}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        try {
            capture.takePicture(outputOptions, cameraExecutor, object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    callback(photoFile.absolutePath, null)
                }
                override fun onError(exception: ImageCaptureException) {
                    callback(null, exception.message ?: "Capture failed")
                }
            })
        } catch (e: Exception) {
            callback(null, e.message ?: "Capture error")
        }
    }

    fun detectFromFile(path: String): Map<String, Any> {
        var bitmap: Bitmap? = null
        try {
            val reqSize = 1600

            // Step 1: decode bounds only to compute inSampleSize
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            if (path.startsWith("content://")) {
                context.contentResolver.openInputStream(Uri.parse(path))?.use { s ->
                    BitmapFactory.decodeStream(s, null, opts)
                }
            } else {
                val file = File(path)
                if (!file.exists()) return emptyMap()
                BitmapFactory.decodeFile(path, opts)
            }

            // Power-of-2 sample size so we land within 2× of reqSize
            var sample = 1
            if (opts.outWidth > reqSize || opts.outHeight > reqSize) {
                while (maxOf(opts.outWidth, opts.outHeight) / (sample * 2) >= reqSize) sample *= 2
            }

            // Step 2: decode at sample size with ARGB_8888 (required by TFLite)
            opts.inJustDecodeBounds = false
            opts.inSampleSize = sample
            opts.inPreferredConfig = Bitmap.Config.ARGB_8888
            bitmap = if (path.startsWith("content://")) {
                context.contentResolver.openInputStream(Uri.parse(path))?.use { s ->
                    BitmapFactory.decodeStream(s, null, opts)
                }
            } else {
                BitmapFactory.decodeFile(path, opts)
            }
            if (bitmap == null) return emptyMap()

            // Step 3: fine-scale to reqSize if still over target
            val bw = bitmap.width; val bh = bitmap.height
            if (bw > reqSize || bh > reqSize) {
                val sc = reqSize.toFloat() / maxOf(bw, bh)
                val scaled = Bitmap.createScaledBitmap(
                    bitmap, (bw * sc).toInt().coerceAtLeast(1), (bh * sc).toInt().coerceAtLeast(1), true
                )
                if (scaled != bitmap) { bitmap.recycle(); bitmap = scaled }
            }

            // Step 4: ensure ARGB_8888 after any format conversion
            if (bitmap.config != Bitmap.Config.ARGB_8888) {
                val converted = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                if (converted != null) { bitmap.recycle(); bitmap = converted }
            }

            // Apply EXIF rotation so detection coordinates match display orientation.
            // BitmapFactory.decodeFile ignores EXIF — camera JPEGs land in raw sensor
            // orientation (landscape) with rotation stored only in EXIF metadata. Without
            // this correction, TFLite detection coordinates are in landscape space while
            // Flutter displays the image in portrait space → markers appear in wrong positions.
            var debugStr = "file: ${bitmap!!.width}x${bitmap!!.height} | EXIF: N/A (content://)"
            if (!path.startsWith("content://")) {
                try {
                    val exif = ExifInterface(path)
                    val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                    val beforeW = bitmap!!.width; val beforeH = bitmap!!.height
                    Log.d("YoloV8View", "detectFromFile: bitmap=${beforeW}x${beforeH} EXIF orientation=$orientation path=$path")
                    val matrix = Matrix()
                    when (orientation) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                        ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                        ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                    }
                    if (!matrix.isIdentity) {
                        val bmp = bitmap!!
                        val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
                        Log.d("YoloV8View", "detectFromFile: rotated to ${rotated.width}x${rotated.height}")
                        debugStr = "EXIF=$orientation | ${beforeW}x${beforeH} → ${rotated.width}x${rotated.height}"
                        if (rotated != bmp) { bmp.recycle(); bitmap = rotated }
                    } else {
                        Log.d("YoloV8View", "detectFromFile: no rotation needed (orientation=$orientation)")
                        debugStr = "EXIF=$orientation (sin rotación) | ${beforeW}x${beforeH}"
                    }
                } catch (e: Exception) {
                    Log.e("YoloV8View", "detectFromFile: EXIF read failed", e)
                    debugStr = "EXIF error: ${e.message}"
                }
            }

            val boxes = detector.detectSync(bitmap)
            val circlesList = boxes.filter { it.clsName.contains("circle", ignoreCase = true) }
                .sortedByDescending { it.cnf }.take(4)
                .flatMap { listOf(it.cx.toDouble(), it.cy.toDouble()) }
                .toMutableList()
            while (circlesList.size < 8) circlesList.add(0.0)
            val eyesList = boxes.filter { it.clsName.contains("eye", ignoreCase = true) }
                .sortedByDescending { it.cnf }.take(2)
                .flatMap { listOf(it.cx.toDouble(), it.cy.toDouble()) }
                .toMutableList()
            while (eyesList.size < 4) eyesList.add(0.0)
            return mapOf("circles" to circlesList, "eyes" to eyesList, "_debug" to debugStr)
        } catch (e: Throwable) {
            Log.e("YoloV8View", "detectFromFile error", e)
            return emptyMap()
        } finally {
            try { bitmap?.recycle() } catch (e: Throwable) {
                Log.e("YoloV8View", "Bitmap cleanup error", e)
            }
        }
    }
}
