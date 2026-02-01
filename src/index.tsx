// src/index.ts

// ============ Components ============
export { NitroMap, default } from './components/NitroMap';

// New specialized marker components
export { PriceMarker } from './components/PriceMarker';
export { ImageMarker } from './components/ImageMarker';

// ============ Types ============
export type { NitroMapProps, NitroMapRef } from './components/NitroMap';

export type {
  Region,
  Coordinate,
  MapType,
  MapPressEvent,
  RegionChangeEvent,
  EdgePadding,
  Camera,
  MapBoundaries,
  MapStyleElement,
  MapStyler,
  MapProvider,
  MapStyle,
  Point,
} from './types/map';

export type {
  MarkerStyle,
  PriceMarkerStyle,
  MarkerColor,
  PriceMarkerConfig,
  ImageMarkerConfig,
  ClusterPressEvent,
  ClusterConfig,
  ClusterAnimationStyle,
  MarkerAnimation,
  MarkerConfig,
  MarkerData,
  MarkerDragEvent,
  MarkerPressEvent,
} from './types/marker';

export {
  NitroMapInitialize,
  IsNitroMapInitialized,
  getDefaultProvider,
} from './modules';

// Marker component props

export type { PriceMarkerProps } from './components/PriceMarker';
export type { ImageMarkerProps } from './components/ImageMarker';

// ============ Utilities ============
// Color helpers - use these to create colors for markers and clusters
export { rgb, hex, Colors } from './utils/colors';
export type { ColorValue } from './utils/colors';
