#pragma once

#include <vector>
#include <memory>
#include <cmath>
#include <algorithm>

namespace nitromap {

/**
 * Point structure for QuadTree
 */
struct Point {
    double x;  // longitude
    double y;  // latitude
    std::string id;

    Point() : x(0), y(0), id("") {}
    Point(double x, double y, const std::string& id) : x(x), y(y), id(id) {}
};

/**
 * Bounding box for spatial queries
 */
struct BoundingBox {
    double minX, minY, maxX, maxY;

    BoundingBox() : minX(0), minY(0), maxX(0), maxY(0) {}
    BoundingBox(double minX, double minY, double maxX, double maxY)
        : minX(minX), minY(minY), maxX(maxX), maxY(maxY) {}

    inline bool contains(const Point& p) const {
        return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
    }

    inline bool intersects(const BoundingBox& other) const {
        return !(other.minX > maxX || other.maxX < minX ||
                 other.minY > maxY || other.maxY < minY);
    }

    inline double centerX() const { return (minX + maxX) / 2.0; }
    inline double centerY() const { return (minY + maxY) / 2.0; }
    inline double width() const { return maxX - minX; }
    inline double height() const { return maxY - minY; }
};

/**
 * QuadTree for efficient spatial indexing
 * Provides O(log n) insert and query operations
 */
class QuadTree {
public:
    static constexpr int MAX_POINTS = 4;
    static constexpr int MAX_DEPTH = 12;

    QuadTree(const BoundingBox& bounds, int depth = 0)
        : bounds_(bounds), depth_(depth), divided_(false) {}

    /**
     * Insert a point into the QuadTree
     * @return true if inserted successfully
     */
    bool insert(const Point& point) {
        // Point outside bounds
        if (!bounds_.contains(point)) {
            return false;
        }

        // If we have capacity and haven't subdivided, add here
        if (points_.size() < MAX_POINTS && !divided_) {
            points_.push_back(point);
            return true;
        }

        // Subdivide if we haven't already and we're not at max depth
        if (!divided_ && depth_ < MAX_DEPTH) {
            subdivide();
        }

        // If we've subdivided, try to insert into children
        if (divided_) {
            if (nw_->insert(point)) return true;
            if (ne_->insert(point)) return true;
            if (sw_->insert(point)) return true;
            if (se_->insert(point)) return true;
        }

        // If we're at max depth, just add to this node
        points_.push_back(point);
        return true;
    }

    /**
     * Query all points within a bounding box
     * @param range The bounding box to query
     * @param found Vector to store found points
     */
    void query(const BoundingBox& range, std::vector<Point>& found) const {
        // Range doesn't intersect this quad
        if (!bounds_.intersects(range)) {
            return;
        }

        // Check points in this node
        for (const auto& point : points_) {
            if (range.contains(point)) {
                found.push_back(point);
            }
        }

        // Recurse into children
        if (divided_) {
            nw_->query(range, found);
            ne_->query(range, found);
            sw_->query(range, found);
            se_->query(range, found);
        }
    }

    /**
     * Query all points within a radius of a center point
     * Uses squared distance for efficiency (no sqrt)
     */
    void queryRadius(double centerX, double centerY, double radius,
                     std::vector<Point>& found) const {
        // Create bounding box around circle for initial filter
        BoundingBox range(
            centerX - radius, centerY - radius,
            centerX + radius, centerY + radius
        );

        if (!bounds_.intersects(range)) {
            return;
        }

        double radiusSquared = radius * radius;

        // Check points in this node
        for (const auto& point : points_) {
            double dx = point.x - centerX;
            double dy = point.y - centerY;
            if (dx * dx + dy * dy <= radiusSquared) {
                found.push_back(point);
            }
        }

        // Recurse into children
        if (divided_) {
            nw_->queryRadius(centerX, centerY, radius, found);
            ne_->queryRadius(centerX, centerY, radius, found);
            sw_->queryRadius(centerX, centerY, radius, found);
            se_->queryRadius(centerX, centerY, radius, found);
        }
    }

    /**
     * Get all points in the tree
     */
    void getAllPoints(std::vector<Point>& allPoints) const {
        for (const auto& point : points_) {
            allPoints.push_back(point);
        }

        if (divided_) {
            nw_->getAllPoints(allPoints);
            ne_->getAllPoints(allPoints);
            sw_->getAllPoints(allPoints);
            se_->getAllPoints(allPoints);
        }
    }

    /**
     * Clear all points from the tree
     */
    void clear() {
        points_.clear();
        divided_ = false;
        nw_.reset();
        ne_.reset();
        sw_.reset();
        se_.reset();
    }

    /**
     * Get total number of points
     */
    size_t size() const {
        size_t count = points_.size();
        if (divided_) {
            count += nw_->size() + ne_->size() + sw_->size() + se_->size();
        }
        return count;
    }

private:
    void subdivide() {
        double cx = bounds_.centerX();
        double cy = bounds_.centerY();

        // Northwest (top-left)
        nw_ = std::make_unique<QuadTree>(
            BoundingBox(bounds_.minX, cy, cx, bounds_.maxY),
            depth_ + 1
        );

        // Northeast (top-right)
        ne_ = std::make_unique<QuadTree>(
            BoundingBox(cx, cy, bounds_.maxX, bounds_.maxY),
            depth_ + 1
        );

        // Southwest (bottom-left)
        sw_ = std::make_unique<QuadTree>(
            BoundingBox(bounds_.minX, bounds_.minY, cx, cy),
            depth_ + 1
        );

        // Southeast (bottom-right)
        se_ = std::make_unique<QuadTree>(
            BoundingBox(cx, bounds_.minY, bounds_.maxX, cy),
            depth_ + 1
        );

        divided_ = true;

        // Move existing points to children
        std::vector<Point> oldPoints = std::move(points_);
        points_.clear();

        for (const auto& point : oldPoints) {
            if (!nw_->insert(point) && !ne_->insert(point) &&
                !sw_->insert(point) && !se_->insert(point)) {
                // Shouldn't happen, but keep point here if it fails
                points_.push_back(point);
            }
        }
    }

    BoundingBox bounds_;
    int depth_;
    bool divided_;
    std::vector<Point> points_;
    std::unique_ptr<QuadTree> nw_, ne_, sw_, se_;
};

} // namespace nitromap
