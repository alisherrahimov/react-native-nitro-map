package com.margelo.nitro.nitromap.clustering

import kotlin.math.sqrt

/**
 * Point in 2D space with optional ID
 */
data class QuadPoint(
    val x: Double,
    val y: Double,
    val id: String = ""
)

/**
 * Bounding box for spatial queries
 */
data class BoundingBox(
    val minX: Double,
    val minY: Double,
    val maxX: Double,
    val maxY: Double
) {
    fun contains(point: QuadPoint): Boolean {
        return point.x >= minX && point.x <= maxX &&
               point.y >= minY && point.y <= maxY
    }

    fun intersects(other: BoundingBox): Boolean {
        return !(other.minX > maxX || other.maxX < minX ||
                 other.minY > maxY || other.maxY < minY)
    }
}

/**
 * High-performance QuadTree for spatial indexing
 * O(log n) point insertion and range queries
 */
class QuadTree(
    private val boundary: BoundingBox,
    private val capacity: Int = MAX_POINTS,
    private val depth: Int = 0
) {
    companion object {
        const val MAX_POINTS = 4
        const val MAX_DEPTH = 12
    }

    private val points = mutableListOf<QuadPoint>()
    private var divided = false
    private var northwest: QuadTree? = null
    private var northeast: QuadTree? = null
    private var southwest: QuadTree? = null
    private var southeast: QuadTree? = null

    /**
     * Insert a point into the tree
     */
    fun insert(point: QuadPoint): Boolean {
        if (!boundary.contains(point)) {
            return false
        }

        if (points.size < capacity || depth >= MAX_DEPTH) {
            points.add(point)
            return true
        }

        if (!divided) {
            subdivide()
        }

        return northwest?.insert(point) == true ||
               northeast?.insert(point) == true ||
               southwest?.insert(point) == true ||
               southeast?.insert(point) == true
    }

    /**
     * Query points within a bounding box
     */
    fun query(range: BoundingBox, found: MutableList<QuadPoint>) {
        if (!boundary.intersects(range)) {
            return
        }

        for (point in points) {
            if (range.contains(point)) {
                found.add(point)
            }
        }

        if (divided) {
            northwest?.query(range, found)
            northeast?.query(range, found)
            southwest?.query(range, found)
            southeast?.query(range, found)
        }
    }

    /**
     * Query points within a circular radius
     */
    fun queryRadius(
        centerX: Double,
        centerY: Double,
        radius: Double,
        found: MutableList<QuadPoint>
    ) {
        val range = BoundingBox(
            centerX - radius,
            centerY - radius,
            centerX + radius,
            centerY + radius
        )

        if (!boundary.intersects(range)) {
            return
        }

        val radiusSq = radius * radius
        for (point in points) {
            val dx = point.x - centerX
            val dy = point.y - centerY
            if (dx * dx + dy * dy <= radiusSq) {
                found.add(point)
            }
        }

        if (divided) {
            northwest?.queryRadius(centerX, centerY, radius, found)
            northeast?.queryRadius(centerX, centerY, radius, found)
            southwest?.queryRadius(centerX, centerY, radius, found)
            southeast?.queryRadius(centerX, centerY, radius, found)
        }
    }

    /**
     * Get all points in the tree
     */
    fun getAllPoints(allPoints: MutableList<QuadPoint>) {
        allPoints.addAll(points)
        if (divided) {
            northwest?.getAllPoints(allPoints)
            northeast?.getAllPoints(allPoints)
            southwest?.getAllPoints(allPoints)
            southeast?.getAllPoints(allPoints)
        }
    }

    /**
     * Clear all points from the tree
     */
    fun clear() {
        points.clear()
        if (divided) {
            northwest?.clear()
            northeast?.clear()
            southwest?.clear()
            southeast?.clear()
            northwest = null
            northeast = null
            southwest = null
            southeast = null
            divided = false
        }
    }

    private fun subdivide() {
        val midX = (boundary.minX + boundary.maxX) / 2
        val midY = (boundary.minY + boundary.maxY) / 2

        northwest = QuadTree(
            BoundingBox(boundary.minX, midY, midX, boundary.maxY),
            capacity,
            depth + 1
        )
        northeast = QuadTree(
            BoundingBox(midX, midY, boundary.maxX, boundary.maxY),
            capacity,
            depth + 1
        )
        southwest = QuadTree(
            BoundingBox(boundary.minX, boundary.minY, midX, midY),
            capacity,
            depth + 1
        )
        southeast = QuadTree(
            BoundingBox(midX, boundary.minY, boundary.maxX, midY),
            capacity,
            depth + 1
        )

        divided = true
    }
}
