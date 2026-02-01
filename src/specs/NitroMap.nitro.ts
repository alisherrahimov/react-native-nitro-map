import type {
  HybridView,
  HybridViewMethods,
  HybridViewProps,
} from 'react-native-nitro-modules';
import type {
  Camera,
  Coordinate,
  EdgePadding,
  MapBoundaries,
  MapPressEvent,
  MapProvider,
  MapStyle,
  MapType,
  Region,
  RegionChangeEvent,
} from '../types/map';
import type {
  ClusterConfig,
  ClusterPressEvent,
  MarkerData,
  MarkerDragEvent,
  MarkerPressEvent,
} from '../types/marker';

/**
 * Props for the NitroMap component
 */
export interface NitroMapProps extends HybridViewProps {
  /**
   * Map provider to use for rendering
   * - `'google'` - Google Maps (default, works on iOS & Android)
   * - `'apple'` - Apple Maps (iOS only, falls back to Google on Android)
   * - `'yandex'` - Yandex Maps (iOS & Android)
   * @default 'google'
   */
  provider?: MapProvider;

  /**
   * Initial region to display when the map loads
   * @example
   * ```tsx
   * initialRegion={{
   *   latitude: 41.299496,
   *   longitude: 69.240073,
   *   latitudeDelta: 0.0922,
   *   longitudeDelta: 0.0421,
   * }}
   * ```
   */
  initialRegion?: Region;

  /**
   * Show the user's current location on the map
   * Requires location permissions
   * @default false
   */
  showsUserLocation?: boolean;

  /**
   * Enable pinch-to-zoom gesture
   * @default true
   */
  zoomEnabled?: boolean;

  /**
   * Enable pan/scroll gesture
   * @default true
   */
  scrollEnabled?: boolean;

  /**
   * Enable rotation gesture (two-finger rotate)
   * @default true
   */
  rotateEnabled?: boolean;

  /**
   * Enable 3D tilt gesture (two-finger vertical pan)
   * @default true
   */
  pitchEnabled?: boolean;

  /**
   * Map display type
   * - `'standard'` - Normal map with roads and labels
   * - `'satellite'` - Satellite imagery
   * - `'hybrid'` - Satellite with roads/labels overlay
   * @default 'standard'
   */
  mapType?: MapType;

  /**
   * Custom JSON styling for the map
   * @see https://mapstyle.withgoogle.com/
   */
  customMapStyle?: MapStyle;

  /**
   * Show the "my location" button on the map
   * @default true
   */
  showsMyLocationButton?: boolean;

  /**
   * Configuration for marker clustering behavior
   */
  clusterConfig?: ClusterConfig;

  /**
   * Enable dark mode styling for the map
   * @default false
   */
  darkMode?: boolean;

  /**
   * Called when the user taps on the map (not on a marker)
   * @param event - Contains the coordinate and screen position of the tap
   */
  onPress?: (event: MapPressEvent) => void;

  /**
   * Called when the user long-presses on the map
   * @param event - Contains the coordinate and screen position of the press
   */
  onLongPress?: (event: MapPressEvent) => void;

  /**
   * Called when the map has finished loading and is ready to use
   */
  onMapReady?: () => void;

  /**
   * Called continuously during region/camera changes
   * Use for live updates while user is panning/zooming
   * @param region - Current region information
   */
  onRegionChange?: (region: RegionChangeEvent) => void;

  /**
   * Called after region/camera change has completed
   * Use for final updates after user finishes panning/zooming
   * @param region - Final region information
   */
  onRegionChangeComplete?: (region: RegionChangeEvent) => void;

  /**
   * Called when any marker on the map is pressed
   * @param event - Contains the marker ID and coordinate
   */
  onMarkerPress?: (event: MarkerPressEvent) => void;

  /**
   * Called when a draggable marker starts being dragged
   * @param event - Contains the marker ID and starting coordinate
   */
  onMarkerDragStart?: (event: MarkerDragEvent) => void;

  /**
   * Called continuously while a marker is being dragged
   * @param event - Contains the marker ID and current coordinate
   */
  onMarkerDrag?: (event: MarkerDragEvent) => void;

  /**
   * Called when a draggable marker is dropped (drag ends)
   * @param event - Contains the marker ID and final coordinate
   */
  onMarkerDragEnd?: (event: MarkerDragEvent) => void;

  /**
   * Called when a cluster of markers is tapped
   * @param event - Contains the cluster coordinate, marker IDs, and count
   */
  onClusterPress?: (event: ClusterPressEvent) => void;
}

/**
 * Methods available on the NitroMap ref
 * Access via `mapRef.current?.methodName()`
 */
export interface NitroMapMethods extends HybridViewMethods {
  /**
   * Animate the map to a new region
   * @param region - Target region to animate to
   * @param duration - Animation duration in milliseconds (default: 500)
   */
  animateToRegion(region: Region, duration?: number): void;

  /**
   * Fit the map to show all provided coordinates
   * @param coordinates - Array of coordinates to fit
   * @param edgePadding - Optional padding from edges
   * @param animated - Whether to animate the transition (default: true)
   */
  fitToCoordinates(
    coordinates: Coordinate[],
    edgePadding?: EdgePadding,
    animated?: boolean
  ): void;

  /**
   * Animate the camera to a specific position
   * @param camera - Target camera configuration
   * @param duration - Animation duration in milliseconds (default: 500)
   */
  animateCamera(camera: Camera, duration?: number): void;

  /**
   * Get the current camera position and configuration
   * @returns Promise resolving to current Camera state
   */
  getCamera(): Promise<Camera>;

  /**
   * Set the camera position instantly (no animation)
   * @param camera - Camera configuration to apply
   */
  setCamera(camera: Camera): void;

  /**
   * Apply a custom style to the map
   * @param style - Map style array (pass undefined to reset to default)
   */
  setMapStyle(style?: MapStyle): void;

  /**
   * Get the current visible map boundaries
   * @returns Promise resolving to northeast/southwest corners
   */
  getMapBoundaries(): Promise<MapBoundaries>;

  /**
   * Enable or disable dark mode styling
   * @param enabled - Whether dark mode should be enabled
   */
  setIsDarkMode(enabled: boolean): void;

  /**
   * Add a single marker to the map
   * @param marker - Full marker data configuration
   */
  addMarker(marker: MarkerData): void;

  /**
   * Add multiple markers at once (more efficient than multiple addMarker calls)
   * @param markers - Array of marker data configurations
   */
  addMarkers(markers: MarkerData[]): void;

  /**
   * Update an existing marker's properties
   * @param marker - Updated marker data (must include existing ID)
   */
  updateMarker(marker: MarkerData): void;

  /**
   * Remove a marker from the map
   * @param id - ID of the marker to remove
   */
  removeMarker(id: string): void;

  /**
   * Select/highlight a marker (shows info window if available)
   * @param id - ID of the marker to select
   */
  selectMarker(id: string): void;

  /**
   * Remove all markers from the map
   */
  clearMarkers(): void;

  /**
   * Enable or disable marker clustering
   * @param enabled - Whether clustering should be enabled
   */
  setClusteringEnabled(enabled: boolean): void;

  /**
   * Force recalculation of clusters
   * Call after dynamically adding/removing markers
   */
  refreshClusters(): void;
}

export type NitroMap = HybridView<NitroMapProps, NitroMapMethods>;
