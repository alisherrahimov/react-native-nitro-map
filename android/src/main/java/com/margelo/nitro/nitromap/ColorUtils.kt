package com.margelo.nitro.nitromap

import android.graphics.Color
import androidx.core.graphics.toColorInt

/**
 * Utility functions for converting color types to Android color integers
 */
object ColorUtils {

    /**
     * Convert MarkerColor (RGBA) to Android color int
     */
    fun fromMarkerColor(color: MarkerColor): Int {
        // Handle alpha: if <= 1.0, treat as 0-1 range and scale to 0-255
        val alpha = if (color.a <= 1.0) (color.a * 255).toInt() else color.a.toInt()
        return Color.argb(
            alpha.coerceIn(0, 255),
            color.r.toInt().coerceIn(0, 255),
            color.g.toInt().coerceIn(0, 255),
            color.b.toInt().coerceIn(0, 255)
        )
    }

    /**
     * Convert ColorValue (String | MarkerColor variant) to Android color int
     */
    fun fromColorValue(colorValue: ColorValue): Int {
        return colorValue.match(
            first = { hexString -> parseHexColor(hexString) },
            second = { markerColor -> fromMarkerColor(markerColor) }
        )
    }

    /**
     * Convert Variant_String_MarkerColor to Android color int
     */
    fun fromVariant(variant: Variant_String_MarkerColor): Int {
        return variant.match(
            first = { hexString -> parseHexColor(hexString) },
            second = { markerColor -> fromMarkerColor(markerColor) }
        )
    }

    /**
     * Parse hex color string to Android color int
     * Supports formats: #RGB, #RRGGBB, #AARRGGBB, and color names
     */
    private fun parseHexColor(hexString: String): Int {
        return try {
            hexString.toColorInt()
        } catch (e: Exception) {
            Color.BLACK // Default fallback
        }
    }

    /**
     * Create a default ColorValue from a MarkerColor
     */
    fun defaultColorValue(r: Double, g: Double, b: Double, a: Double = 255.0): ColorValue {
        return ColorValue.create(MarkerColor(r, g, b, a))
    }
}
