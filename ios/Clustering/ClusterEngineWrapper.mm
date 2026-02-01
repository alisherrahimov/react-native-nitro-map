#import "ClusterEngineWrapper.h"
#include "ClusterEngine.hpp"

using namespace nitromap;

// MARK: - ClusterMarkerPoint

@implementation ClusterMarkerPoint
@end

// MARK: - ClusterData

@implementation ClusterData
@end

// MARK: - ClusteringResult

@implementation ClusteringResult
@end

// MARK: - ClusterEngineWrapper

@interface ClusterEngineWrapper () {
    std::unique_ptr<ClusterEngine> _engine;
}
@end

@implementation ClusterEngineWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = std::make_unique<ClusterEngine>();
    }
    return self;
}

- (void)setClusterRadius:(double)radiusPixels {
    if (_engine) {
        _engine->setClusterRadius(radiusPixels);
    }
}

- (void)setMinClusterSize:(NSInteger)size {
    if (_engine) {
        _engine->setMinClusterSize(static_cast<int>(size));
    }
}

- (void)setMaxZoom:(double)zoom {
    if (_engine) {
        _engine->setMaxZoom(zoom);
    }
}

- (void)addMarkerWithId:(NSString *)markerId
               latitude:(double)latitude
              longitude:(double)longitude {
    if (_engine && markerId) {
        MarkerPoint marker(
            [markerId UTF8String],
            latitude,
            longitude
        );
        _engine->addMarker(marker);
    }
}

- (void)removeMarkerWithId:(NSString *)markerId {
    if (_engine && markerId) {
        _engine->removeMarker([markerId UTF8String]);
    }
}

- (void)clearMarkers {
    if (_engine) {
        _engine->clearMarkers();
    }
}

- (NSUInteger)markerCount {
    if (_engine) {
        return _engine->getMarkerCount();
    }
    return 0;
}

- (ClusteringResult *)clusterWithMinLat:(double)minLat
                                 maxLat:(double)maxLat
                                 minLon:(double)minLon
                                 maxLon:(double)maxLon
                                   zoom:(double)zoom
                               mapWidth:(double)mapWidth
                              mapHeight:(double)mapHeight {
    ClusteringResult *result = [[ClusteringResult alloc] init];
    result.clusters = @[];
    result.singleMarkers = @[];

    if (!_engine) {
        return result;
    }

    // Call C++ clustering
    ClusterResult cppResult = _engine->cluster(
        minLat, maxLat, minLon, maxLon,
        zoom, mapWidth, mapHeight
    );

    // Convert clusters
    NSMutableArray<ClusterData *> *clusters = [NSMutableArray array];
    for (const auto& cluster : cppResult.clusters) {
        ClusterData *clusterData = [[ClusterData alloc] init];
        clusterData.latitude = cluster.latitude;
        clusterData.longitude = cluster.longitude;
        clusterData.count = cluster.count;

        NSMutableArray<NSString *> *markerIds = [NSMutableArray array];
        for (const auto& markerId : cluster.markerIds) {
            [markerIds addObject:[NSString stringWithUTF8String:markerId.c_str()]];
        }
        clusterData.markerIds = markerIds;

        [clusters addObject:clusterData];
    }
    result.clusters = clusters;

    // Convert single markers
    NSMutableArray<ClusterMarkerPoint *> *singleMarkers = [NSMutableArray array];
    for (const auto& marker : cppResult.singleMarkers) {
        ClusterMarkerPoint *point = [[ClusterMarkerPoint alloc] init];
        point.markerId = [NSString stringWithUTF8String:marker.id.c_str()];
        point.latitude = marker.latitude;
        point.longitude = marker.longitude;
        [singleMarkers addObject:point];
    }
    result.singleMarkers = singleMarkers;

    return result;
}

@end
