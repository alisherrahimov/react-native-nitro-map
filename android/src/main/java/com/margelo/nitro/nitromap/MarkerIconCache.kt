package com.margelo.nitro.nitromap

import android.graphics.Bitmap
import android.util.LruCache
import kotlin.math.roundToInt

/**
 * Singleton cache for marker icon bitmaps using Flyweight pattern. Shares identical bitmaps across
 * markers to reduce memory usage.
 *
 * Memory savings: 10,000 markers × 100KB each = 1GB → ~50MB with caching
 */
object MarkerIconCache {

    // Calculate max cache size as 1/8th of available memory, capped at 50MB
    private val maxMemory = Runtime.getRuntime().maxMemory() / 1024
    private val cacheSize = minOf((maxMemory / 8).toInt(), 50 * 1024) // 50MB max in KB

    // LRU cache for price marker bitmaps
    private val priceMarkerCache =
            object : LruCache<String, Bitmap>(cacheSize) {
                override fun sizeOf(key: String, bitmap: Bitmap): Int {
                    // Size in KB
                    return bitmap.byteCount / 1024
                }

                override fun entryRemoved(
                        evicted: Boolean,
                        key: String,
                        oldValue: Bitmap,
                        newValue: Bitmap?
                ) {
                    // Recycle bitmap when evicted to free memory immediately
                    if (evicted && !oldValue.isRecycled) {
                        oldValue.recycle()
                    }
                }
            }

    // Separate cache for image markers (URL/base64 images)
    private val imageMarkerCache =
            object : LruCache<String, Bitmap>(cacheSize / 2) {
                override fun sizeOf(key: String, bitmap: Bitmap): Int {
                    return bitmap.byteCount / 1024
                }

                override fun entryRemoved(
                        evicted: Boolean,
                        key: String,
                        oldValue: Bitmap,
                        newValue: Bitmap?
                ) {
                    if (evicted && !oldValue.isRecycled) {
                        oldValue.recycle()
                    }
                }
            }

    // Cache for cluster icons
    private val clusterCache =
            object : LruCache<String, Bitmap>(10 * 1024) { // 10MB
                override fun sizeOf(key: String, bitmap: Bitmap): Int {
                    return bitmap.byteCount / 1024
                }
            }

    // Track cache stats for debugging
    private var hitCount = 0
    private var missCount = 0

    /** Get cached price marker bitmap or null if not cached */
    fun getPriceMarker(key: String): Bitmap? {
        val cached = priceMarkerCache.get(key)
        if (cached != null) {
            hitCount++
            if (hitCount % 1000 == 0) {
                logCacheStats()
            }
        }
        return cached
    }

    /** Cache a price marker bitmap */
    fun putPriceMarker(key: String, bitmap: Bitmap) {
        missCount++
        priceMarkerCache.put(key, bitmap)
    }

    /** Get cached image marker bitmap or null if not cached */
    fun getImageMarker(key: String): Bitmap? {
        return imageMarkerCache.get(key)
    }

    /** Cache an image marker bitmap */
    fun putImageMarker(key: String, bitmap: Bitmap) {
        imageMarkerCache.put(key, bitmap)
    }

    /** Get cached cluster icon or null if not cached */
    fun getClusterIcon(key: String): Bitmap? {
        return clusterCache.get(key)
    }

    /** Cache a cluster icon bitmap */
    fun putClusterIcon(key: String, bitmap: Bitmap) {
        clusterCache.put(key, bitmap)
    }

    /**
     * Generate normalized cache key for price markers. Identical prices share the same cached
     * bitmap (Flyweight pattern).
     */
    fun priceMarkerKey(price: String, currency: String, selected: Boolean): String {
        return "price_${price}_${currency}_${selected}"
    }

    /**
     * Generate normalized cache key for image markers. Rounds dimensions to reduce unique keys
     * (more cache hits).
     */
    fun imageMarkerKey(
            source: String,
            width: Double,
            height: Double,
            cornerRadius: Double
    ): String {
        // Round to nearest 5 to reduce unique textures
        val w = ((width / 5).roundToInt() * 5)
        val h = ((height / 5).roundToInt() * 5)
        val r = ((cornerRadius / 5).roundToInt() * 5)
        val sourceHash = source.hashCode()
        return "image_${sourceHash}_${w}_${h}_${r}"
    }

    /** Generate cache key for cluster icons */
    fun clusterKey(count: Int, backgroundColor: Int): String {
        // Bucket counts to reduce unique icons
        val bucket =
                when {
                    count < 10 -> count
                    count < 100 -> (count / 10) * 10
                    count < 1000 -> (count / 100) * 100
                    else -> (count / 1000) * 1000
                }
        return "cluster_${bucket}_${backgroundColor}"
    }

    /** Clear all caches (call on memory warning) */
    fun clear() {
        priceMarkerCache.evictAll()
        imageMarkerCache.evictAll()
        clusterCache.evictAll()
        hitCount = 0
        missCount = 0
        android.util.Log.d("MarkerIconCache", "Cache cleared")
    }

    /** Trim caches to specified level (0.0 to 1.0) */
    fun trimToLevel(level: Float) {
        val targetSize = (cacheSize * level).toInt()
        priceMarkerCache.trimToSize(targetSize)
        imageMarkerCache.trimToSize(targetSize / 2)
    }

    private fun logCacheStats() {
        val hitRate =
                if (hitCount + missCount > 0) {
                    (hitCount * 100) / (hitCount + missCount)
                } else 0
        android.util.Log.d(
                "MarkerIconCache",
                "Cache stats: hits=$hitCount, misses=$missCount, hitRate=$hitRate%, " +
                        "priceSize=${priceMarkerCache.size()}KB, imageSize=${imageMarkerCache.size()}KB"
        )
    }
}
