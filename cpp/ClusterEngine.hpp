#pragma once

#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <string>
#include <memory>
#include <cmath>
#include <algorithm>
#include "QuadTree.hpp"

namespace nitromap {

/**
 * Marker point with associated data
 */
struct MarkerPoint {
    std::string id;
    double latitude;
    double longitude;

    MarkerPoint() : id(""), latitude(0), longitude(0) {}
    MarkerPoint(const std::string& id, double lat, double lon)
        : id(id), latitude(lat), longitude(lon) {}
};

/**
 * Result cluster containing multiple markers
 */
struct Cluster {
    double latitude;   // Cluster center latitude
    double longitude;  // Cluster center longitude
    std::vector<std::string> markerIds;
    int count;

    Cluster() : latitude(0), longitude(0), count(0) {}
    Cluster(double lat, double lon) : latitude(lat), longitude(lon), count(0) {}
};

/**
 * Result of clustering operation
 */
struct ClusterResult {
    std::vector<Cluster> clusters;
    std::vector<MarkerPoint> singleMarkers;

    void clear() {
        clusters.clear();
        singleMarkers.clear();
    }
};

/**
 * High-performance clustering engine using QuadTree spatial indexing
 *
 * Algorithm: Grid-based clustering with QuadTree acceleration
 * Complexity: O(n log n) average case, vs O(n²) for naive approach
 *
 * The algorithm:
 * 1. Build QuadTree from all markers
 * 2. Divide visible region into grid cells based on zoom level
 * 3. For each cell, query nearby markers using QuadTree
 * 4. Group nearby markers into clusters
 * 5. Return clusters and single markers
 */
class ClusterEngine {
public:
    ClusterEngine();
    ~ClusterEngine() = default;

    // Configuration
    void setClusterRadius(double radiusInPixels);
    void setMinClusterSize(int size);
    void setMaxZoom(double zoom);

    // Marker management
    void addMarker(const MarkerPoint& marker);
    void addMarkers(const std::vector<MarkerPoint>& markers);
    void removeMarker(const std::string& id);
    void clearMarkers();
    size_t getMarkerCount() const;

    /**
     * Main clustering function
     *
     * @param visibleMinLat Minimum latitude of visible region
     * @param visibleMaxLat Maximum latitude of visible region
     * @param visibleMinLon Minimum longitude of visible region
     * @param visibleMaxLon Maximum longitude of visible region
     * @param zoomLevel Current map zoom level (0-22)
     * @param mapWidth Map width in pixels
     * @param mapHeight Map height in pixels
     * @return ClusterResult containing clusters and single markers
     */
    ClusterResult cluster(
        double visibleMinLat,
        double visibleMaxLat,
        double visibleMinLon,
        double visibleMaxLon,
        double zoomLevel,
        double mapWidth,
        double mapHeight
    );

private:
    // All markers stored by ID
    std::unordered_map<std::string, MarkerPoint> markers_;

    // Configuration
    double clusterRadiusPixels_ = 60.0;  // Cluster radius in pixels
    int minClusterSize_ = 2;             // Minimum markers to form cluster
    double maxZoom_ = 20.0;              // Don't cluster above this zoom

    // Rebuild QuadTree when markers change
    bool needsRebuild_ = true;
    std::unique_ptr<QuadTree> quadTree_;

    // Helper functions
    void rebuildQuadTree();

    /**
     * Convert pixel distance to coordinate distance at given zoom level
     * Uses Web Mercator projection approximation
     */
    double pixelsToCoordDistance(double pixels, double zoom, double latitude) const;

    /**
     * Calculate distance between two coordinates in approximate "units"
     * Not true meters, but proportional for clustering purposes
     */
    double coordinateDistance(double lat1, double lon1, double lat2, double lon2) const;

    /**
     * Grid-based clustering algorithm
     * Much faster than naive O(n²) approach
     */
    void gridBasedCluster(
        const BoundingBox& visibleBounds,
        double clusterDistance,
        ClusterResult& result
    );
};

// ============================================================================
// IMPLEMENTATION (Header-only for easier integration)
// ============================================================================

inline ClusterEngine::ClusterEngine() {
    // Initialize with world bounds
    quadTree_ = std::make_unique<QuadTree>(
        BoundingBox(-180.0, -90.0, 180.0, 90.0)
    );
}

inline void ClusterEngine::setClusterRadius(double radiusInPixels) {
    clusterRadiusPixels_ = radiusInPixels;
}

inline void ClusterEngine::setMinClusterSize(int size) {
    minClusterSize_ = std::max(2, size);
}

inline void ClusterEngine::setMaxZoom(double zoom) {
    maxZoom_ = zoom;
}

inline void ClusterEngine::addMarker(const MarkerPoint& marker) {
    markers_[marker.id] = marker;
    needsRebuild_ = true;
}

inline void ClusterEngine::addMarkers(const std::vector<MarkerPoint>& markers) {
    for (const auto& marker : markers) {
        markers_[marker.id] = marker;
    }
    needsRebuild_ = true;
}

inline void ClusterEngine::removeMarker(const std::string& id) {
    markers_.erase(id);
    needsRebuild_ = true;
}

inline void ClusterEngine::clearMarkers() {
    markers_.clear();
    quadTree_->clear();
    needsRebuild_ = true;
}

inline size_t ClusterEngine::getMarkerCount() const {
    return markers_.size();
}

inline void ClusterEngine::rebuildQuadTree() {
    if (!needsRebuild_) return;

    quadTree_->clear();
    quadTree_ = std::make_unique<QuadTree>(
        BoundingBox(-180.0, -90.0, 180.0, 90.0)
    );

    for (const auto& pair : markers_) {
        const auto& marker = pair.second;
        Point p(marker.longitude, marker.latitude, marker.id);
        quadTree_->insert(p);
    }

    needsRebuild_ = false;
}

inline double ClusterEngine::pixelsToCoordDistance(
    double pixels, double zoom, double latitude
) const {
    // Web Mercator: meters per pixel at equator at zoom 0 = 156543.03392
    // At zoom z: meters_per_pixel = 156543.03392 / 2^z
    // Then convert to degrees (approx 111320 meters per degree at equator)
    // Adjust for latitude using cos(latitude)

    double metersPerPixel = 156543.03392 / std::pow(2.0, zoom);
    double metersPerDegree = 111320.0 * std::cos(latitude * M_PI / 180.0);

    if (metersPerDegree < 1.0) metersPerDegree = 1.0;  // Avoid division by zero near poles

    return (pixels * metersPerPixel) / metersPerDegree;
}

inline double ClusterEngine::coordinateDistance(
    double lat1, double lon1, double lat2, double lon2
) const {
    // Simple Euclidean distance for clustering purposes
    // Good enough for small distances at same zoom level
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    return std::sqrt(dLat * dLat + dLon * dLon);
}

inline void ClusterEngine::gridBasedCluster(
    const BoundingBox& visibleBounds,
    double clusterDistance,
    ClusterResult& result
) {
    // Get all points in visible area
    std::vector<Point> visiblePoints;
    quadTree_->query(visibleBounds, visiblePoints);

    if (visiblePoints.empty()) {
        return;
    }

    // Track which markers have been processed
    std::unordered_set<std::string> processed;

    // Process each point
    for (const auto& point : visiblePoints) {
        if (processed.count(point.id) > 0) {
            continue;
        }

        // Find all nearby points using QuadTree radius query
        std::vector<Point> nearbyPoints;
        quadTree_->queryRadius(
            point.x, point.y, clusterDistance, nearbyPoints
        );

        // Filter to only include points within visible bounds
        // This ensures cluster count matches the actual visible markers when expanded
        std::vector<Point> visibleNearbyPoints;
        for (const auto& nearby : nearbyPoints) {
            if (visibleBounds.contains(nearby)) {
                visibleNearbyPoints.push_back(nearby);
            }
        }

        // Filter out already processed points
        std::vector<Point> unprocessedNearby;
        for (const auto& nearby : visibleNearbyPoints) {
            if (processed.count(nearby.id) == 0) {
                unprocessedNearby.push_back(nearby);
            }
        }

        if (unprocessedNearby.size() >= static_cast<size_t>(minClusterSize_)) {
            // Create cluster
            Cluster cluster;
            double sumLat = 0, sumLon = 0;

            for (const auto& p : unprocessedNearby) {
                cluster.markerIds.push_back(p.id);
                sumLat += p.y;  // y is latitude
                sumLon += p.x;  // x is longitude
                processed.insert(p.id);
            }

            cluster.count = static_cast<int>(unprocessedNearby.size());
            cluster.latitude = sumLat / cluster.count;
            cluster.longitude = sumLon / cluster.count;

            result.clusters.push_back(std::move(cluster));
        } else {
            // Single marker (or less than minimum cluster size)
            for (const auto& p : unprocessedNearby) {
                if (processed.count(p.id) == 0) {
                    auto it = markers_.find(p.id);
                    if (it != markers_.end()) {
                        result.singleMarkers.push_back(it->second);
                    }
                    processed.insert(p.id);
                }
            }
        }
    }
}

inline ClusterResult ClusterEngine::cluster(
    double visibleMinLat,
    double visibleMaxLat,
    double visibleMinLon,
    double visibleMaxLon,
    double zoomLevel,
    double mapWidth,
    double mapHeight
) {
    ClusterResult result;

    // No markers? Return empty result
    if (markers_.empty()) {
        return result;
    }

    // Above max zoom? Return all as single markers
    if (zoomLevel >= maxZoom_) {
        for (const auto& pair : markers_) {
            const auto& marker = pair.second;
            // Only include markers in visible area
            if (marker.latitude >= visibleMinLat && marker.latitude <= visibleMaxLat &&
                marker.longitude >= visibleMinLon && marker.longitude <= visibleMaxLon) {
                result.singleMarkers.push_back(marker);
            }
        }
        return result;
    }

    // Rebuild QuadTree if needed
    rebuildQuadTree();

    // Calculate cluster distance in coordinate units
    double centerLat = (visibleMinLat + visibleMaxLat) / 2.0;
    double clusterDistance = pixelsToCoordDistance(
        clusterRadiusPixels_, zoomLevel, centerLat
    );

    // Expand visible bounds slightly to include markers at edges
    double padding = clusterDistance * 2;
    BoundingBox visibleBounds(
        visibleMinLon - padding,
        visibleMinLat - padding,
        visibleMaxLon + padding,
        visibleMaxLat + padding
    );

    // Run grid-based clustering
    gridBasedCluster(visibleBounds, clusterDistance, result);

    return result;
}

} // namespace nitromap
