// src/components/NitroMapContext.tsx
import { createContext } from 'react';
import type { NitroMapMethods } from '../specs/NitroMap.nitro';
import type { Coordinate } from '../types/map';

// Marker event handlers
export interface MarkerHandlers {
  onPress?: () => void;
  onDragStart?: (coordinate: Coordinate) => void;
  onDrag?: (coordinate: Coordinate) => void;
  onDragEnd?: (coordinate: Coordinate) => void;
}

// Context value type
export interface NitroMapContextValue {
  // Map ref for calling native methods
  mapRef: NitroMapMethods | null;

  // Register marker event handlers
  registerMarkerHandler: (markerId: string, handlers: MarkerHandlers) => void;

  // Unregister marker event handlers
  unregisterMarkerHandler: (markerId: string) => void;

  // Get handlers for a specific marker (used internally)
  getMarkerHandler: (markerId: string) => MarkerHandlers | undefined;
}

// Create context with null default
export const NitroMapContext = createContext<NitroMapContextValue | null>(null);

// Provider display name for debugging
NitroMapContext.displayName = 'NitroMapContext';
