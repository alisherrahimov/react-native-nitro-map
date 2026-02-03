package com.margelo.nitro.nitromap

import android.content.Context
import android.graphics.*
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import kotlin.math.roundToInt
import androidx.core.graphics.toColorInt

/**
 * Generator for cluster marker icons
 */
class ClusterIconGenerator(private val context: Context) {

    private var backgroundColor = "#007AFF".toColorInt() // iOS blue
    private var textColor = Color.WHITE
    private var borderColor = Color.WHITE
    private var borderWidth = 2f

    private val iconCache = mutableMapOf<Int, BitmapDescriptor>()

    fun updateConfig(config: ClusterConfig?) {
        config?.let {
            backgroundColor = ColorUtils.fromColorValue(it.backgroundColor)
            textColor = ColorUtils.fromColorValue(it.textColor)
            borderColor = ColorUtils.fromColorValue(it.borderColor)
            borderWidth = it.borderWidth.toFloat()
            // Clear cache when config changes
            iconCache.clear()
        }
    }

    fun getClusterIcon(count: Int): BitmapDescriptor {
        // Check cache first
        iconCache[count]?.let { return it }

        val density = context.resources.displayMetrics.density

        // Size based on count
        val baseSize = when {
            count < 10 -> 40
            count < 100 -> 48
            count < 1000 -> 56
            else -> 64
        }
        val size = (baseSize * density).roundToInt()

        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Draw background circle
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = backgroundColor
            style = Paint.Style.FILL
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f - borderWidth * density, bgPaint)

        // Draw border
        if (borderWidth > 0) {
            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = borderColor
                style = Paint.Style.STROKE
                strokeWidth = borderWidth * density
            }
            canvas.drawCircle(
                size / 2f,
                size / 2f,
                size / 2f - borderWidth * density / 2,
                borderPaint
            )
        }

        // Draw count text
        val text = formatCount(count)
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textSize = when {
                count < 10 -> 16 * density
                count < 100 -> 14 * density
                count < 1000 -> 12 * density
                else -> 10 * density
            }
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }

        val textBounds = Rect()
        textPaint.getTextBounds(text, 0, text.length, textBounds)
        val textY = size / 2f + textBounds.height() / 2f
        canvas.drawText(text, size / 2f, textY, textPaint)

        val descriptor = BitmapDescriptorFactory.fromBitmap(bitmap)
        iconCache[count] = descriptor
        return descriptor
    }

    private fun formatCount(count: Int): String {
        return when {
            count >= 1000000 -> "${count / 1000000}M"
            count >= 1000 -> "${count / 1000}K"
            else -> count.toString()
        }
    }

    fun clearCache() {
        iconCache.clear()
    }
}
