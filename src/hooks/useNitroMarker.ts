// src/hooks/useNitroMarker.ts
import { useContext, useEffect, useRef, useCallback } from 'react';
import {
  NitroMapContext,
  type MarkerHandlers,
} from '../context/NitroMapContext';
import type { MarkerConfig, MarkerAnimation } from '../types/marker';
import type { Coordinate, Point } from '../types/map';

/**
 * Base marker data structure for internal use
 */
export interface BaseMarkerData {
  id: string;
  coordinate: Coordinate;
  title?: string;
  description?: string;
  draggable: boolean;
  opacity: number;
  rotation: number;
  zIndex: number;
  anchor: Point;
  clusteringEnabled: boolean;
  config: MarkerConfig;
  animation: MarkerAnimation;
}

/**
 * Props shared by all marker components
 */
export interface CommonMarkerProps {
  /** Unique identifier for the marker */
  id?: string;

  /** Geographic coordinates where the marker should be placed */
  coordinate: Coordinate;

  /** Title shown in info window when marker is tapped */
  title?: string;

  /** Description shown in info window below the title */
  description?: string;

  /** Whether the marker can be dragged by the user */
  draggable?: boolean;

  /** Marker opacity (0 = transparent, 1 = opaque) */
  opacity?: number;

  /** Rotation angle in degrees (clockwise from north) */
  rotation?: number;

  /** Z-index for controlling overlap order */
  zIndex?: number;

  /** Anchor point for positioning (0-1 range) */
  anchor?: Point;

  /** Whether this marker should be included in clustering */
  clusteringEnabled?: boolean;

  /** Animation when marker appears on the map */
  animation?: MarkerAnimation;

  /** Called when the marker is tapped */
  onPress?: () => void;

  /** Called when the marker starts being dragged */
  onDragStart?: (coordinate: Coordinate) => void;

  /** Called continuously while the marker is being dragged */
  onDrag?: (coordinate: Coordinate) => void;

  /** Called when the marker is dropped (drag ends) */
  onDragEnd?: (coordinate: Coordinate) => void;
}

// ID generator
let markerIdCounter = 0;
const generateMarkerId = (prefix: string) =>
  `${prefix}_${++markerIdCounter}_${Date.now()}`;

/**
 * Hook options for useNitroMarker
 */
export interface UseNitroMarkerOptions {
  /** ID prefix for auto-generated IDs */
  idPrefix: string;

  /** User-provided ID (optional) */
  providedId?: string;

  /** Event handlers */
  handlers: MarkerHandlers;

  /** Function to build marker data - receives the generated/provided markerId */
  buildMarkerData: (markerId: string) => BaseMarkerData;
}

/**
 * Shared hook for all marker components
 * Handles ID generation, context registration, and marker lifecycle
 */
export function useNitroMarker({
  idPrefix,
  providedId,
  handlers,
  buildMarkerData,
}: UseNitroMarkerOptions): string {
  // Generate stable ID
  const markerId = useRef(providedId || generateMarkerId(idPrefix)).current;

  // Get map context
  const mapContext = useContext(NitroMapContext);

  // Track if marker has been added
  const isAddedRef = useRef(false);

  // ============ Register Event Handlers ============
  useEffect(() => {
    if (!mapContext) {
      console.warn(`${idPrefix} must be used inside NitroMap`);
      return;
    }

    // Register handlers
    mapContext.registerMarkerHandler(markerId, handlers);

    // Cleanup on unmount
    return () => {
      mapContext.unregisterMarkerHandler(markerId);
    };
    // We intentionally depend on individual handler properties instead of the handlers object
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    markerId,
    mapContext,
    handlers.onPress,
    handlers.onDragStart,
    handlers.onDrag,
    handlers.onDragEnd,
    idPrefix,
  ]);

  // ============ Add Marker on Mount, Remove on Unmount ============
  // NOTE: mapContext is a ref object, so we must track mapContext.mapRef separately
  const mapRef = mapContext?.mapRef;

  useEffect(() => {
    if (!mapRef) {
      return;
    }

    // Add marker on mount
    mapRef.addMarker(buildMarkerData(markerId));
    isAddedRef.current = true;

    // Remove marker only on unmount
    return () => {
      mapRef?.removeMarker(markerId);
      isAddedRef.current = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapRef, markerId]); // mapRef is now properly tracked

  // ============ Update Marker when props change ============
  useEffect(() => {
    // Skip if not yet added or no map ref
    if (!isAddedRef.current || !mapContext?.mapRef) {
      return;
    }

    // Update marker with new data
    mapContext.mapRef.updateMarker(buildMarkerData(markerId));
  }, [mapContext, buildMarkerData, markerId]);

  return markerId;
}

/**
 * Create stable handlers object that won't cause unnecessary re-renders
 */
export function useMarkerHandlers(
  onPress?: () => void,
  onDragStart?: (coordinate: Coordinate) => void,
  onDrag?: (coordinate: Coordinate) => void,
  onDragEnd?: (coordinate: Coordinate) => void
): MarkerHandlers {
  return useCallback(
    () => ({
      onPress,
      onDragStart,
      onDrag,
      onDragEnd,
    }),
    [onPress, onDragStart, onDrag, onDragEnd]
  )();
}
