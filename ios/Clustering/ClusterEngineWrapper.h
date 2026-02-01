#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/// Single marker point for clustering
@interface ClusterMarkerPoint : NSObject
@property (nonatomic, copy) NSString *markerId;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@end

/// Cluster result containing multiple markers
@interface ClusterData : NSObject
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, strong) NSArray<NSString *> *markerIds;
@property (nonatomic, assign) NSInteger count;
@end

/// Full clustering result
@interface ClusteringResult : NSObject
@property (nonatomic, strong) NSArray<ClusterData *> *clusters;
@property (nonatomic, strong) NSArray<ClusterMarkerPoint *> *singleMarkers;
@end

/// Objective-C++ wrapper for C++ ClusterEngine
/// Provides high-performance clustering using QuadTree spatial indexing
@interface ClusterEngineWrapper : NSObject

/// Initialize the cluster engine
- (instancetype)init;

/// Configuration
- (void)setClusterRadius:(double)radiusPixels;
- (void)setMinClusterSize:(NSInteger)size;
- (void)setMaxZoom:(double)zoom;

/// Marker management
- (void)addMarkerWithId:(NSString *)markerId
               latitude:(double)latitude
              longitude:(double)longitude;
- (void)removeMarkerWithId:(NSString *)markerId;
- (void)clearMarkers;
- (NSUInteger)markerCount;

/// Perform clustering
/// @param minLat Minimum latitude of visible region
/// @param maxLat Maximum latitude of visible region
/// @param minLon Minimum longitude of visible region
/// @param maxLon Maximum longitude of visible region
/// @param zoom Current zoom level
/// @param mapWidth Map width in pixels
/// @param mapHeight Map height in pixels
/// @return Clustering result with clusters and single markers
- (ClusteringResult *)clusterWithMinLat:(double)minLat
                                 maxLat:(double)maxLat
                                 minLon:(double)minLon
                                 maxLon:(double)maxLon
                                   zoom:(double)zoom
                               mapWidth:(double)mapWidth
                              mapHeight:(double)mapHeight;

@end

NS_ASSUME_NONNULL_END
