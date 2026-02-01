import type { Coordinate, Point } from './map';
import type { ColorValue } from '../utils/colors';

/**
 * Visual style of the marker
 * - `'default'` - Standard Google Maps marker
 * - `'price'` - Simple price tag
 * - `'image'` - Custom image marker
 * - `'priceMarker'` - Full-featured price marker with currency
 * - `'reactView'` - React Native view marker (internal use by NitroCustomMarker)
 *
 * Note: For React Native views as markers, use the NitroCustomMarker component.
 */
export type MarkerStyle = 'default' | 'image' | 'priceMarker';

/**
 * Animation type for individual markers when they appear
 * - `'none'` - No animation
 * - `'pop'` - Pop/bounce effect
 * - `'fadeIn'` - Fade in animation
 */
export type MarkerAnimation = 'none' | 'pop' | 'fadeIn';

/**
 * Animation style for cluster expand/collapse
 * - `'default'` - Standard Google Maps Utils animation
 * - `'bounce'` - Markers bounce when appearing
 * - `'scale'` - Scale up from 0 to full size
 * - `'fade'` - Fade in/out
 * - `'spring'` - Spring effect animation
 */
export type ClusterAnimationStyle =
  | 'default'
  | 'bounce'
  | 'scale'
  | 'fade'
  | 'spring';

/**
 * Style configuration for price markers
 * Colors can be hex strings ("#FF0000", "#F00") or MarkerColor objects
 */
export type PriceMarkerStyle = {
  /** Price text to display (e.g., "9M", "150K") */
  price: string;
  /** Currency code (e.g., "UZS", "USD", "EUR") */
  currency: string;
  /** Whether the marker is in selected state (changes colors) */
  selected: boolean;
  /** Background color in normal state (hex string or MarkerColor) */
  backgroundColor?: ColorValue;
  /** Background color when selected (hex string or MarkerColor) */
  selectedBackgroundColor?: ColorValue;
  /** Text color in normal state (hex string or MarkerColor) */
  textColor?: ColorValue;
  /** Text color when selected (hex string or MarkerColor) */
  selectedTextColor?: ColorValue;
  /** Font size in pixels */
  fontSize?: number;
  /** Horizontal padding in pixels */
  paddingHorizontal?: number;
  /** Vertical padding in pixels */
  paddingVertical?: number;
  /** Shadow opacity (0-1) */
  shadowOpacity?: number;
};

/**
 * RGBA color representation
 * All values range from 0-255
 */
export type MarkerColor = {
  /** Red component (0-255) */
  r: number;
  /** Green component (0-255) */
  g: number;
  /** Blue component (0-255) */
  b: number;
  /** Alpha/opacity component (0-255) */
  a: number;
};

/**
 * Configuration for price-style markers
 */
export type PriceMarkerConfig = {
  /** Price text to display */
  price: string;
  /** Background color */
  backgroundColor: MarkerColor;
  /** Text color */
  textColor: MarkerColor;
  /** Font size in pixels */
  fontSize: number;
  /** Corner radius in pixels */
  cornerRadius: number;
  /** Whether marker is in selected state */
  selected: boolean;
};

/**
 * Configuration for image-style markers
 * Colors can be hex strings ("#FF0000", "#F00") or MarkerColor objects
 */
export type ImageMarkerConfig = {
  /** URL of the image to display */
  imageUrl?: string;
  /** Base64-encoded image data (alternative to URL) */
  imageBase64?: string;
  /** Image width in pixels */
  width: number;
  /** Image height in pixels */
  height: number;
  /** Corner radius in pixels */
  cornerRadius: number;
  /** Border thickness in pixels */
  borderWidth: number;
  /** Border color (hex string or MarkerColor) */
  borderColor: ColorValue;
};

/**
 * Combined marker configuration based on style type
 */
export type MarkerConfig = {
  /** The marker style type */
  style: MarkerStyle;
  /** Image marker config (when style is 'image') */
  image?: ImageMarkerConfig;
  /** Price marker style config (when style is 'priceMarker') */
  priceMarker?: PriceMarkerStyle;
  /** React view marker config (when style is 'reactView') */
};

/**
 * Complete marker data structure used internally
 */
export type MarkerData = {
  /** Unique identifier for the marker */
  id: string;
  /** Geographic coordinates of the marker */
  coordinate: Coordinate;
  /** Title shown in info window */
  title?: string;
  /** Description shown in info window */
  description?: string;
  /** Whether the marker can be dragged */
  draggable: boolean;
  /** Marker opacity (0-1) */
  opacity: number;
  /** Rotation in degrees */
  rotation: number;
  /** Z-index for overlapping markers */
  zIndex: number;
  /** Anchor point for positioning (0-1 range) */
  anchor: Point;
  /** Visual configuration for the marker */
  config: MarkerConfig;
  /** Whether this marker should be included in clustering */
  clusteringEnabled: boolean;
  /** Animation when marker appears */
  animation: MarkerAnimation;
};

/**
 * Event data when a marker is pressed
 */
export type MarkerPressEvent = {
  /** ID of the pressed marker */
  id: string;
  /** Coordinates where marker was pressed */
  coordinate: Coordinate;
};

/**
 * Event data during marker drag operations
 */
export type MarkerDragEvent = {
  /** ID of the dragged marker */
  id: string;
  /** Current coordinates during drag */
  coordinate: Coordinate;
};

/**
 * Event data when a cluster is pressed
 */
export type ClusterPressEvent = {
  /** Coordinates of the cluster */
  coordinate: Coordinate;
  /** IDs of all markers in the cluster */
  markerIds: string[];
  /** Number of markers in the cluster */
  count: number;
};

/**
 * Configuration for marker clustering behavior
 * Colors can be hex strings ("#FF0000", "#F00") or MarkerColor objects
 */
export type ClusterConfig = {
  /** Enable or disable clustering */
  enabled: boolean;
  /** Minimum number of markers to form a cluster */
  minimumClusterSize: number;
  /** Maximum zoom level at which clustering occurs */
  maxZoom: number;
  /** Background color of cluster circles (hex string or MarkerColor) */
  backgroundColor: ColorValue;
  /** Text color for cluster count numbers (hex string or MarkerColor) */
  textColor: ColorValue;
  /** Border thickness in pixels */
  borderWidth: number;
  /** Border color of cluster circles (hex string or MarkerColor) */
  borderColor: ColorValue;
  /** Enable cluster animations */
  animatesClusters: boolean;
  /** Animation duration in seconds (e.g., 0.3) */
  animationDuration: number;
  /** Animation style for cluster expand/collapse */
  animationStyle: ClusterAnimationStyle;
};
