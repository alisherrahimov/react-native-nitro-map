// src/components/PriceMarker.tsx
import { memo, useCallback, useMemo } from 'react';
import {
  useNitroMarker,
  type CommonMarkerProps,
} from '../hooks/useNitroMarker';
import type { MarkerColor } from '../types/marker';
import { parseColor, type ColorValue } from '../utils/colors';

/**
 * Props for the PriceMarker component
 */
export interface PriceMarkerProps extends CommonMarkerProps {
  /**
   * Price text to display (e.g., "9M", "150K")
   * @required
   */
  price: string;

  /**
   * Currency code to display (e.g., "UZS", "USD")
   * If provided, uses the full price marker style with currency
   */
  currency?: string;

  /**
   * Whether the marker is in selected state
   * Changes background and text colors when true
   * @default false
   */
  selected?: boolean;

  /**
   * Background color of the marker (hex string like "#FF0000" or MarkerColor object)
   * @default Colors.white
   */
  backgroundColor?: ColorValue;

  /**
   * Text color of the marker (hex string like "#FF0000" or MarkerColor object)
   * @default Colors.black
   */
  textColor?: ColorValue;

  /**
   * Font size in pixels
   * @default 14
   */
  fontSize?: number;

  /**
   * Corner radius in pixels (only for simple price style)
   * @default 8
   */
  cornerRadius?: number;

  /**
   * Background color when marker is selected (hex string like "#FF0000" or MarkerColor object)
   */
  selectedBackgroundColor?: ColorValue;

  /**
   * Text color when marker is selected (hex string like "#FF0000" or MarkerColor object)
   */
  selectedTextColor?: ColorValue;

  /**
   * Horizontal padding in pixels
   */
  paddingHorizontal?: number;

  /**
   * Vertical padding in pixels
   */
  paddingVertical?: number;

  /**
   * Shadow opacity (0-1)
   */
  shadowOpacity?: number;
}

// ============ Custom Memo Comparison ============
const arePropsEqual = (
  prevProps: PriceMarkerProps,
  nextProps: PriceMarkerProps
): boolean => {
  // Compare primitive props
  if (
    prevProps.id !== nextProps.id ||
    prevProps.price !== nextProps.price ||
    prevProps.currency !== nextProps.currency ||
    prevProps.selected !== nextProps.selected ||
    prevProps.title !== nextProps.title ||
    prevProps.description !== nextProps.description ||
    prevProps.draggable !== nextProps.draggable ||
    prevProps.opacity !== nextProps.opacity ||
    prevProps.rotation !== nextProps.rotation ||
    prevProps.zIndex !== nextProps.zIndex ||
    prevProps.clusteringEnabled !== nextProps.clusteringEnabled ||
    prevProps.animation !== nextProps.animation ||
    prevProps.fontSize !== nextProps.fontSize ||
    prevProps.cornerRadius !== nextProps.cornerRadius ||
    prevProps.paddingHorizontal !== nextProps.paddingHorizontal ||
    prevProps.paddingVertical !== nextProps.paddingVertical ||
    prevProps.shadowOpacity !== nextProps.shadowOpacity
  ) {
    return false;
  }

  // Compare coordinate
  if (
    prevProps.coordinate?.latitude !== nextProps.coordinate?.latitude ||
    prevProps.coordinate?.longitude !== nextProps.coordinate?.longitude
  ) {
    return false;
  }

  // Compare anchor
  if (
    prevProps.anchor?.x !== nextProps.anchor?.x ||
    prevProps.anchor?.y !== nextProps.anchor?.y
  ) {
    return false;
  }

  // Compare colors (handles both hex strings and MarkerColor objects)
  const compareColors = (
    a: ColorValue | undefined,
    b: ColorValue | undefined
  ) => {
    if (!a && !b) return true;
    if (!a || !b) return false;
    // If both are strings, compare directly
    if (typeof a === 'string' && typeof b === 'string') return a === b;
    // If types differ, not equal
    if (typeof a !== typeof b) return false;
    // Both are MarkerColor objects
    const aColor = a as MarkerColor;
    const bColor = b as MarkerColor;
    return (
      aColor.r === bColor.r &&
      aColor.g === bColor.g &&
      aColor.b === bColor.b &&
      aColor.a === bColor.a
    );
  };

  if (
    !compareColors(prevProps.backgroundColor, nextProps.backgroundColor) ||
    !compareColors(prevProps.textColor, nextProps.textColor) ||
    !compareColors(
      prevProps.selectedBackgroundColor,
      nextProps.selectedBackgroundColor
    ) ||
    !compareColors(prevProps.selectedTextColor, nextProps.selectedTextColor)
  ) {
    return false;
  }

  return true;
};

/**
 * PriceMarker - Display price tags on the map
 *
 * @example Simple price tag
 * ```tsx
 * <PriceMarker
 *   coordinate={{ latitude: 41.29, longitude: 69.24 }}
 *   price="150K"
 * />
 * ```
 *
 * @example Full price marker with currency
 * ```tsx
 * <PriceMarker
 *   coordinate={{ latitude: 41.30, longitude: 69.25 }}
 *   price="9M"
 *   currency="UZS"
 *   selected={isSelected}
 *   onPress={() => setSelected(true)}
 * />
 * ```
 */
export const PriceMarker = memo(function PriceMarker({
  // Required
  coordinate,
  price,

  // Identification
  id,

  // Price-specific props
  currency,
  selected = false,
  backgroundColor,
  textColor,
  fontSize = 14,
  // cornerRadius prop kept for backwards compatibility but not used
  selectedBackgroundColor,
  selectedTextColor,
  paddingHorizontal,
  paddingVertical,
  shadowOpacity,

  // Common props
  title,
  description,
  draggable = false,
  opacity = 1,
  rotation = 0,
  zIndex = 0,
  anchor = { x: 0.5, y: 0.5 },
  clusteringEnabled = true,
  animation = 'none',

  // Events
  onPress,
  onDragStart,
  onDrag,
  onDragEnd,
}: PriceMarkerProps) {
  // Build marker config based on style
  const buildMarkerConfig = useCallback(() => {
    // Always use priceMarker style - 'price' is not a valid MarkerStyle
    return {
      style: 'priceMarker' as const,
      priceMarker: {
        price,
        currency: currency ?? '', // Default to empty string if no currency
        selected,
        backgroundColor: parseColor(backgroundColor),
        selectedBackgroundColor: parseColor(selectedBackgroundColor),
        textColor: parseColor(textColor),
        selectedTextColor: parseColor(selectedTextColor),
        fontSize,
        paddingHorizontal,
        paddingVertical,
        shadowOpacity,
      },
    };
  }, [
    price,
    currency,
    selected,
    backgroundColor,
    textColor,
    fontSize,
    selectedBackgroundColor,
    selectedTextColor,
    paddingHorizontal,
    paddingVertical,
    shadowOpacity,
  ]);

  // Memoize handlers
  const handlers = useMemo(
    () => ({
      onPress,
      onDragStart,
      onDrag,
      onDragEnd,
    }),
    [onPress, onDragStart, onDrag, onDragEnd]
  );

  // Build full marker data
  const buildMarkerData = useCallback(
    (markerId: string) => ({
      id: markerId,
      coordinate,
      title,
      description,
      draggable,
      opacity,
      rotation,
      zIndex,
      anchor,
      clusteringEnabled,
      config: buildMarkerConfig(),
      animation,
    }),
    [
      coordinate,
      title,
      description,
      draggable,
      opacity,
      rotation,
      zIndex,
      anchor,
      clusteringEnabled,
      buildMarkerConfig,
      animation,
    ]
  );

  // Use shared marker hook
  useNitroMarker({
    idPrefix: 'price_marker',
    providedId: id,
    handlers,
    buildMarkerData,
  });

  // Render nothing - marker is rendered natively
  return null;
}, arePropsEqual);

export default PriceMarker;
