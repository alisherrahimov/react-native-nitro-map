/**
 * Geographic region definition
 * Defines a rectangular region on the map using center point and deltas
 */
export type Region = {
  /** Center latitude of the region */
  latitude: number;
  /** Center longitude of the region */
  longitude: number;
  /** Latitude span (height of visible region) */
  latitudeDelta: number;
  /** Longitude span (width of visible region) */
  longitudeDelta: number;
};

/**
 * Geographic coordinate (latitude/longitude pair)
 */
export type Coordinate = {
  /** Latitude in degrees (-90 to 90) */
  latitude: number;
  /** Longitude in degrees (-180 to 180) */
  longitude: number;
};

/**
 * Map display type
 * - `'standard'` - Normal map with roads and labels
 * - `'satellite'` - Satellite imagery
 * - `'hybrid'` - Satellite with roads/labels overlay
 */
export type MapType = 'standard' | 'satellite' | 'hybrid';

/**
 * Map provider to use for rendering
 * - `'google'` - Google Maps (iOS & Android)
 * - `'apple'` - Apple Maps (iOS only, falls back to Google on Android)
 * - `'yandex'` - Yandex Maps (iOS & Android)
 */
export type MapProvider = 'google' | 'apple' | 'yandex';

/**
 * Screen point (x/y coordinates in pixels)
 */
export type Point = {
  /** X coordinate in pixels */
  x: number;
  /** Y coordinate in pixels */
  y: number;
};

/**
 * Event data when map is pressed
 */
export type MapPressEvent = {
  /** Geographic coordinates of the press location */
  coordinate: Coordinate;
  /** Screen position of the press in pixels */
  position: Point;
};

/**
 * Event data during map region changes
 */
export type RegionChangeEvent = {
  /** The new/current region */
  region: Region;
  /** Whether the change was caused by user gesture */
  isGesture: boolean;
};

/**
 * Padding values for map edges (in pixels)
 */
export type EdgePadding = {
  /** Top padding in pixels */
  top: number;
  /** Right padding in pixels */
  right: number;
  /** Bottom padding in pixels */
  bottom: number;
  /** Left padding in pixels */
  left: number;
};

/**
 * Camera position and orientation
 */
export type Camera = {
  /** Center point the camera is looking at */
  center: Coordinate;
  /** Tilt angle in degrees (0 = looking straight down, 90 = looking at horizon) */
  pitch: number;
  /** Rotation/bearing in degrees (0 = north up) */
  heading: number;
  /** Altitude/elevation in meters */
  altitude: number;
  /** Zoom level (higher = closer) */
  zoom: number;
};

/**
 * Visible map boundaries (bounding box)
 */
export type MapBoundaries = {
  /** Northeast corner of visible area */
  northEast: Coordinate;
  /** Southwest corner of visible area */
  southWest: Coordinate;
};

/**
 * Individual style element for Google Maps styling
 */
export type MapStyler = {
  /** Color in hex format (e.g., "#FF0000") */
  color?: string;
  /** Visibility: "on", "off", or "simplified" */
  visibility?: string;
  /** Stroke/line weight in pixels */
  weight?: number;
  /** Color saturation adjustment (-100 to 100) */
  saturation?: number;
  /** Lightness adjustment (-100 to 100) */
  lightness?: number;
  /** Gamma adjustment (0.01 to 10.0) */
  gamma?: number;
};

/**
 * Map style element targeting specific features
 * @see https://developers.google.com/maps/documentation/javascript/style-reference
 */
export type MapStyleElement = {
  /** Feature type to style (e.g., "road", "water", "poi") */
  featureType?: string;
  /** Element type to style (e.g., "geometry", "labels") */
  elementType?: string;
  /** Style modifications to apply */
  stylers: MapStyler[];
};

/**
 * Complete map style definition
 * Array of style elements to customize map appearance
 * @example
 * ```ts
 * const darkStyle: MapStyle = [
 *   { featureType: "all", stylers: [{ saturation: -100 }] },
 *   { featureType: "water", stylers: [{ color: "#0e171d" }] }
 * ];
 * ```
 */
export type MapStyle = MapStyleElement[];
