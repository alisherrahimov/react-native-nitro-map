// src/components/NitroMap.tsx
import React, {
  forwardRef,
  useImperativeHandle,
  useCallback,
  useRef,
  useState,
  useMemo,
  memo,
} from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { getHostComponent, callback } from 'react-native-nitro-modules';

import type {
  NitroMapMethods,
  NitroMapProps as NitroMapPropsSpec,
} from '../specs/NitroMap.nitro';

import {
  NitroMapContext,
  type MarkerHandlers,
} from '../context/NitroMapContext';
import type {
  ClusterPressEvent,
  MarkerDragEvent,
  MarkerPressEvent,
  MarkerColor,
} from '../types/marker';
import type { MapStyle } from '../types/map';
import { getDefaultProvider } from '../modules';
import { parseColor, Colors } from '../utils/colors';

// Re-export all types
export * from '../specs/NitroMap.nitro';
export * from '../context/NitroMapContext';

// Load native config (uses package name for proper resolution when installed from npm)

const NitroMapConfig = require('react-native-nitro-map/nitrogen/generated/shared/json/NitroMapConfig.json');

// Get native component
const NitroMapHostComponent = getHostComponent<
  NitroMapPropsSpec,
  NitroMapMethods
>('NitroMap', () => NitroMapConfig);

// Extended props with style and children
export interface NitroMapProps
  extends Omit<NitroMapPropsSpec, 'style' | 'hybridRef'> {
  style?: StyleProp<ViewStyle>;
  children?: React.ReactNode;
}

// Ref type
export type NitroMapRef = NitroMapMethods;

/**
 * NitroMap - High-performance Google Maps component with native markers
 */
const NitroMapInner = forwardRef<NitroMapRef, NitroMapProps>(
  (
    {
      style,
      children,
      provider,
      initialRegion,
      showsUserLocation = false,
      zoomEnabled = true,
      scrollEnabled = true,
      rotateEnabled = true,
      pitchEnabled = true,
      darkMode = false,
      mapType = 'standard',
      showsMyLocationButton = false,
      clusterConfig,
      onPress,
      onLongPress,
      onMapReady,
      onRegionChange,
      onRegionChangeComplete,
      onMarkerPress,
      onMarkerDragStart,
      onMarkerDrag,
      onMarkerDragEnd,
      onClusterPress,
      ...rest
    },
    ref
  ) => {
    // Native ref
    const nativeRef = useRef<NitroMapMethods | null>(null);

    // Marker handlers registry
    const markerHandlersRef = useRef<Map<string, MarkerHandlers>>(new Map());

    // Track if map is ready
    const [isReady, setIsReady] = useState(false);

    // Expose methods via ref
    useImperativeHandle(ref, () => ({
      animateToRegion: (region, duration) => {
        nativeRef.current?.animateToRegion(region, duration);
      },
      fitToCoordinates: (coordinates, edgePadding, animated) => {
        nativeRef.current?.fitToCoordinates(coordinates, edgePadding, animated);
      },
      animateCamera: (camera, duration) => {
        nativeRef.current?.animateCamera(camera, duration);
      },
      getCamera: () => {
        if (!nativeRef.current) {
          return Promise.reject(new Error('Map not ready'));
        }
        return nativeRef.current.getCamera();
      },
      setCamera: (camera) => {
        nativeRef.current?.setCamera(camera);
      },
      getMapBoundaries: () => {
        if (!nativeRef.current) {
          return Promise.reject(new Error('Map not ready'));
        }
        return nativeRef.current.getMapBoundaries();
      },
      addMarker: (marker) => {
        nativeRef.current?.addMarker(marker);
      },
      addMarkers: (markers) => {
        nativeRef.current?.addMarkers(markers);
      },
      updateMarker: (marker) => {
        nativeRef.current?.updateMarker(marker);
      },
      removeMarker: (id) => {
        nativeRef.current?.removeMarker(id);
      },
      clearMarkers: () => {
        nativeRef.current?.clearMarkers();
      },
      setClusteringEnabled: (enabled) => {
        nativeRef.current?.setClusteringEnabled(enabled);
      },
      refreshClusters: () => {
        nativeRef.current?.refreshClusters();
      },
      selectMarker: (id: string) => {
        nativeRef.current?.selectMarker(id);
      },
      setMapStyle: (mapStyle: MapStyle) => {
        nativeRef.current?.setMapStyle(mapStyle);
      },
      setIsDarkMode: (enabled: boolean) => {
        nativeRef.current?.setIsDarkMode(enabled);
      },
    }));

    // Handle hybridRef callback

    // Map ready handler
    const handleMapReady = useCallback(() => {
      setIsReady(true);
      onMapReady?.();
    }, [onMapReady]);

    // Marker press handler - calls both local handler and prop
    const handleMarkerPress = useCallback(
      (event: MarkerPressEvent) => {
        const handlers = markerHandlersRef.current.get(event.id);
        handlers?.onPress?.();
        onMarkerPress?.(event);
      },
      [onMarkerPress]
    );

    // Marker drag start handler
    const handleMarkerDragStart = useCallback(
      (event: MarkerDragEvent) => {
        const handlers = markerHandlersRef.current.get(event.id);
        handlers?.onDragStart?.(event.coordinate);
        onMarkerDragStart?.(event);
      },
      [onMarkerDragStart]
    );

    // Marker drag handler
    const handleMarkerDrag = useCallback(
      (event: MarkerDragEvent) => {
        const handlers = markerHandlersRef.current.get(event.id);
        handlers?.onDrag?.(event.coordinate);
        onMarkerDrag?.(event);
      },
      [onMarkerDrag]
    );

    // Marker drag end handler
    const handleMarkerDragEnd = useCallback(
      (event: MarkerDragEvent) => {
        const handlers = markerHandlersRef.current.get(event.id);
        handlers?.onDragEnd?.(event.coordinate);
        onMarkerDragEnd?.(event);
      },
      [onMarkerDragEnd]
    );

    // Cluster press handler
    const handleClusterPress = useCallback(
      (event: ClusterPressEvent) => {
        onClusterPress?.(event);
      },
      [onClusterPress]
    );

    // Context value - memoized to prevent unnecessary re-renders
    const contextValue = useRef({
      mapRef: null as NitroMapMethods | null,

      registerMarkerHandler: (id: string, handlers: MarkerHandlers) => {
        markerHandlersRef.current.set(id, handlers);
      },

      unregisterMarkerHandler: (id: string) => {
        markerHandlersRef.current.delete(id);
      },

      getMarkerHandler: (id: string) => {
        return markerHandlersRef.current.get(id);
      },
    }).current;

    // Memoize style to prevent new array on every render
    const combinedStyle = useMemo(() => [styles.default, style], [style]);

    // Parse cluster config colors (convert hex strings to MarkerColor objects)
    const parsedClusterConfig = useMemo(() => {
      if (!clusterConfig) return undefined;

      const defaultColor: MarkerColor = Colors.blue;
      const defaultTextColor: MarkerColor = Colors.white;
      const defaultBorderColor: MarkerColor = Colors.white;

      return {
        ...clusterConfig,
        backgroundColor: parseColor(clusterConfig.backgroundColor) ?? defaultColor,
        textColor: parseColor(clusterConfig.textColor) ?? defaultTextColor,
        borderColor: parseColor(clusterConfig.borderColor) ?? defaultBorderColor,
      };
    }, [clusterConfig]);

    // Memoize hybridRef callback
    const hybridRefCallback = useMemo(
      () =>
        callback((native: NitroMapMethods | null) => {
          nativeRef.current = native;
          contextValue.mapRef = native;
        }),
      [contextValue]
    );

    // Memoize event callbacks to prevent re-creating on every render
    const memoizedCallbacks = useMemo(
      () => ({
        onPress: callback(onPress),
        onLongPress: callback(onLongPress),
        onMapReady: callback(handleMapReady),
        onRegionChange: callback(onRegionChange),
        onRegionChangeComplete: callback(onRegionChangeComplete),
        onMarkerPress: callback(handleMarkerPress),
        onMarkerDragStart: callback(handleMarkerDragStart),
        onMarkerDrag: callback(handleMarkerDrag),
        onMarkerDragEnd: callback(handleMarkerDragEnd),
        onClusterPress: callback(handleClusterPress),
      }),
      [
        onPress,
        onLongPress,
        handleMapReady,
        onRegionChange,
        onRegionChangeComplete,
        handleMarkerPress,
        handleMarkerDragStart,
        handleMarkerDrag,
        handleMarkerDragEnd,
        handleClusterPress,
      ]
    );

    return (
      <NitroMapContext.Provider value={contextValue}>
        <NitroMapHostComponent
          style={combinedStyle}
          hybridRef={hybridRefCallback}
          provider={provider ?? getDefaultProvider()}
          initialRegion={initialRegion}
          showsUserLocation={showsUserLocation}
          zoomEnabled={zoomEnabled}
          scrollEnabled={scrollEnabled}
          rotateEnabled={rotateEnabled}
          pitchEnabled={pitchEnabled}
          mapType={mapType}
          darkMode={darkMode}
          showsMyLocationButton={showsMyLocationButton}
          clusterConfig={parsedClusterConfig}
          onPress={memoizedCallbacks.onPress}
          onLongPress={memoizedCallbacks.onLongPress}
          onMapReady={memoizedCallbacks.onMapReady}
          onRegionChange={memoizedCallbacks.onRegionChange}
          onRegionChangeComplete={memoizedCallbacks.onRegionChangeComplete}
          onMarkerPress={memoizedCallbacks.onMarkerPress}
          onMarkerDragStart={memoizedCallbacks.onMarkerDragStart}
          onMarkerDrag={memoizedCallbacks.onMarkerDrag}
          onMarkerDragEnd={memoizedCallbacks.onMarkerDragEnd}
          onClusterPress={memoizedCallbacks.onClusterPress}
          {...rest}
        />
        {/* Only render children when map is ready */}
        {isReady && children}
      </NitroMapContext.Provider>
    );
  }
);

NitroMapInner.displayName = 'NitroMap';

// ============ Custom Props Comparison ============
// Deep compare map props to prevent unnecessary re-renders
const areMapPropsEqual = (
  prevProps: NitroMapProps,
  nextProps: NitroMapProps
): boolean => {
  // Compare primitive props
  if (
    prevProps.provider !== nextProps.provider ||
    prevProps.showsUserLocation !== nextProps.showsUserLocation ||
    prevProps.zoomEnabled !== nextProps.zoomEnabled ||
    prevProps.scrollEnabled !== nextProps.scrollEnabled ||
    prevProps.rotateEnabled !== nextProps.rotateEnabled ||
    prevProps.pitchEnabled !== nextProps.pitchEnabled ||
    prevProps.darkMode !== nextProps.darkMode ||
    prevProps.mapType !== nextProps.mapType ||
    prevProps.showsMyLocationButton !== nextProps.showsMyLocationButton
  ) {
    return false;
  }

  // Compare initialRegion (deep)
  const prevRegion = prevProps.initialRegion;
  const nextRegion = nextProps.initialRegion;
  if (prevRegion && nextRegion) {
    if (
      prevRegion.latitude !== nextRegion.latitude ||
      prevRegion.longitude !== nextRegion.longitude ||
      prevRegion.latitudeDelta !== nextRegion.latitudeDelta ||
      prevRegion.longitudeDelta !== nextRegion.longitudeDelta
    ) {
      return false;
    }
  } else if (prevRegion !== nextRegion) {
    return false;
  }

  // Compare clusterConfig (deep)
  const prevCluster = prevProps.clusterConfig;
  const nextCluster = nextProps.clusterConfig;
  if (prevCluster && nextCluster) {
    if (
      prevCluster.enabled !== nextCluster.enabled ||
      prevCluster.minimumClusterSize !== nextCluster.minimumClusterSize ||
      prevCluster.maxZoom !== nextCluster.maxZoom
    ) {
      return false;
    }
  } else if (prevCluster !== nextCluster) {
    return false;
  }

  // Compare style (shallow - StyleProp is usually stable)
  if (prevProps.style !== nextProps.style) {
    return false;
  }

  // IMPORTANT: We MUST compare children!
  // Children like PriceMarker use hooks that call native methods.
  // If we skip children comparison, new markers won't be added to the map.
  if (prevProps.children !== nextProps.children) {
    return false;
  }

  // Note: We intentionally do NOT compare callbacks here.
  // - Callbacks are memoized internally and passed via callback().

  return true;
};

// Memoized NitroMap to prevent unnecessary re-renders
const NitroMap = memo(NitroMapInner, areMapPropsEqual);

const styles = StyleSheet.create({
  default: {
    flex: 1,
  },
});

export { NitroMap };
export default NitroMap;
