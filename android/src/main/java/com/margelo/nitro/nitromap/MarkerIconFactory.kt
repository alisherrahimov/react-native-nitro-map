package com.margelo.nitro.nitromap

import android.content.Context
import android.graphics.*
import android.util.Base64
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import java.net.URL
import kotlin.math.roundToInt

/** Factory for creating marker icons from MarkerData configuration */
object MarkerIconFactory {

    private var reactContext: com.facebook.react.bridge.ReactContext? = null

    /** Set the React context for view capture (call this from HybridNitroMap initialization) */
    fun setReactContext(context: com.facebook.react.bridge.ReactContext?) {
        reactContext = context
    }

    fun createIcon(context: Context, markerData: MarkerData): BitmapDescriptor? {
        return when (markerData.config.style) {
            MarkerStyle.IMAGE -> createImageMarkerIcon(context, markerData.config.image)
            MarkerStyle.PRICEMARKER ->
                    createPriceMarkerStyleIcon(context, markerData.config.priceMarker)
            MarkerStyle.DEFAULT -> null
        }
    }

    private fun createPriceMarkerStyleIcon(
            context: Context,
            config: PriceMarkerStyle?
    ): BitmapDescriptor? {
        config ?: return null

        // Generate cache key (Flyweight pattern)
        val cacheKey =
                MarkerIconCache.priceMarkerKey(config.price, config.currency, config.selected)

        // Check cache first
        MarkerIconCache.getPriceMarker(cacheKey)?.let { cachedBitmap ->
            return BitmapDescriptorFactory.fromBitmap(cachedBitmap)
        }

        val density = context.resources.displayMetrics.density
        val priceText = "${config.price} ${config.currency}"
        val fontSize = (config.fontSize ?: 14.0) * density
        val paddingH = (config.paddingHorizontal ?: 12.0) * density
        val paddingV = (config.paddingVertical ?: 8.0) * density

        val textPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    textSize = fontSize.toFloat()
                    typeface = Typeface.DEFAULT_BOLD
                    textAlign = Paint.Align.LEFT
                }

        // Set colors based on selection state
        val bgColor =
                if (config.selected) {
                    config.selectedBackgroundColor?.let { colorFromMarkerColor(it) }
                            ?: Color.parseColor("#E53935") // Red for selected
                } else {
                    config.backgroundColor?.let { colorFromMarkerColor(it) } ?: Color.WHITE
                }

        val textColor =
                if (config.selected) {
                    config.selectedTextColor?.let { colorFromMarkerColor(it) } ?: Color.WHITE
                } else {
                    config.textColor?.let { colorFromMarkerColor(it) } ?: Color.BLACK
                }

        textPaint.color = textColor

        val textBounds = Rect()
        textPaint.getTextBounds(priceText, 0, priceText.length, textBounds)

        val arrowHeight = 8 * density
        val width = textBounds.width() + paddingH * 2
        val height = textBounds.height() + paddingV * 2 + arrowHeight
        val cornerRadius = 8 * density

        val bitmap =
                Bitmap.createBitmap(
                        width.roundToInt(),
                        height.roundToInt(),
                        Bitmap.Config.ARGB_8888
                )
        val canvas = Canvas(bitmap)

        val bgPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = bgColor
                    style = Paint.Style.FILL
                }

        // Add shadow
        val shadowPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.BLACK
                    alpha = ((config.shadowOpacity ?: 0.2) * 255).toInt()
                    maskFilter = BlurMaskFilter((4 * density).toFloat(), BlurMaskFilter.Blur.NORMAL)
                }

        val bubbleRect =
                RectF(
                        (2 * density).toFloat(),
                        0f,
                        (width - 2 * density).toFloat(),
                        (height - arrowHeight).toFloat()
                )
        canvas.drawRoundRect(
                bubbleRect.apply { offset(0f, (2 * density).toFloat()) },
                cornerRadius.toFloat(),
                cornerRadius.toFloat(),
                shadowPaint
        )

        bubbleRect.offset(0f, (-2 * density).toFloat())
        canvas.drawRoundRect(bubbleRect, cornerRadius.toFloat(), cornerRadius.toFloat(), bgPaint)

        // Draw arrow
        val path =
                Path().apply {
                    moveTo((width / 2 - arrowHeight).toFloat(), (height - arrowHeight).toFloat())
                    lineTo((width / 2).toFloat(), height.toFloat())
                    lineTo((width / 2 + arrowHeight).toFloat(), (height - arrowHeight).toFloat())
                    close()
                }
        canvas.drawPath(path, bgPaint)

        // Draw text
        val textX = paddingH.toFloat()
        val textY = paddingV.toFloat() + textBounds.height()
        canvas.drawText(priceText, textX, textY, textPaint)

        // Cache the bitmap for reuse
        MarkerIconCache.putPriceMarker(cacheKey, bitmap)

        return BitmapDescriptorFactory.fromBitmap(bitmap)
    }

    private fun createImageMarkerIcon(
            context: Context,
            config: ImageMarkerConfig?
    ): BitmapDescriptor? {
        config ?: return null

        val imageSource = config.imageBase64 ?: config.imageUrl ?: ""

        // Generate cache key (Flyweight pattern)
        val cacheKey =
                MarkerIconCache.imageMarkerKey(
                        imageSource,
                        config.width,
                        config.height,
                        config.cornerRadius
                )

        // Check cache first
        MarkerIconCache.getImageMarker(cacheKey)?.let { cachedBitmap ->
            return BitmapDescriptorFactory.fromBitmap(cachedBitmap)
        }

        val density = context.resources.displayMetrics.density
        val width = (config.width * density).roundToInt()
        val height = (config.height * density).roundToInt()
        val cornerRadius = config.cornerRadius * density
        val borderWidth = config.borderWidth * density

        var sourceImage: Bitmap? = null

        // Try to load image from base64
        config.imageBase64?.let { base64 ->
            try {
                val bytes = Base64.decode(base64, Base64.DEFAULT)
                sourceImage = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Try to load from URL (blocking - should be done on background thread in production)
        if (sourceImage == null) {
            config.imageUrl?.let { urlString ->
                try {
                    val url = URL(urlString)
                    val connection = url.openConnection()
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    val inputStream = connection.getInputStream()
                    sourceImage = BitmapFactory.decodeStream(inputStream)
                    inputStream.close()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val clipPath =
                Path().apply {
                    addRoundRect(
                            RectF(0f, 0f, width.toFloat(), height.toFloat()),
                            cornerRadius.toFloat(),
                            cornerRadius.toFloat(),
                            Path.Direction.CW
                    )
                }
        canvas.clipPath(clipPath)

        // Draw image or placeholder
        sourceImage?.let { img ->
            val scaledBitmap = Bitmap.createScaledBitmap(img, width, height, true)
            canvas.drawBitmap(scaledBitmap, 0f, 0f, null)
            if (scaledBitmap != img) scaledBitmap.recycle()
        }
                ?: run {
                    val placeholderPaint = Paint().apply { color = Color.LTGRAY }
                    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), placeholderPaint)
                }

        // Draw border
        if (borderWidth > 0) {
            val borderPaint =
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = colorFromMarkerColor(config.borderColor)
                        style = Paint.Style.STROKE
                        strokeWidth = borderWidth.toFloat()
                    }
            canvas.drawRoundRect(
                    RectF(
                            borderWidth.toFloat() / 2,
                            borderWidth.toFloat() / 2,
                            width - borderWidth.toFloat() / 2,
                            height - borderWidth.toFloat() / 2
                    ),
                    cornerRadius.toFloat(),
                    cornerRadius.toFloat(),
                    borderPaint
            )
        }

        // Cache the bitmap for reuse
        MarkerIconCache.putImageMarker(cacheKey, bitmap)

        return BitmapDescriptorFactory.fromBitmap(bitmap)
    }

    private fun colorFromMarkerColor(color: MarkerColor): Int {
        // Handle alpha: if <= 1.0, treat as 0-1 range and scale to 0-255
        val alpha = if (color.a <= 1.0) (color.a * 255).toInt() else color.a.toInt()
        return Color.argb(
                alpha.coerceIn(0, 255),
                color.r.toInt().coerceIn(0, 255),
                color.g.toInt().coerceIn(0, 255),
                color.b.toInt().coerceIn(0, 255)
        )
    }
}
