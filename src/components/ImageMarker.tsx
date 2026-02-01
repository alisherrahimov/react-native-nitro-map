// src/components/ImageMarker.tsx
import { memo, useCallback, useMemo } from 'react';
import {
  useNitroMarker,
  type CommonMarkerProps,
} from '../hooks/useNitroMarker';
import type { MarkerColor } from '../types/marker';
import { Colors, parseColor, type ColorValue } from '../utils/colors';

/**
 * Props for the ImageMarker component
 */
export interface ImageMarkerProps extends CommonMarkerProps {
  /**
   * URL of the image to display
   * Either imageUrl or imageBase64 is required
   */
  imageUrl?: string;

  /**
   * Base64-encoded image data (alternative to imageUrl)
   * Either imageUrl or imageBase64 is required
   */
  imageBase64?: string;

  /**
   * Image width in pixels
   * @default 50
   */
  width?: number;

  /**
   * Image height in pixels
   * @default 50
   */
  height?: number;

  /**
   * Corner radius in pixels
   * @default 8
   */
  cornerRadius?: number;

  /**
   * Border thickness in pixels
   * @default 0
   */
  borderWidth?: number;

  /**
   * Border color (hex string like "#FF0000" or MarkerColor object)
   */
  borderColor?: ColorValue;
}

// ============ Custom Memo Comparison ============
const arePropsEqual = (
  prevProps: ImageMarkerProps,
  nextProps: ImageMarkerProps
): boolean => {
  if (
    prevProps.id !== nextProps.id ||
    prevProps.imageUrl !== nextProps.imageUrl ||
    prevProps.imageBase64 !== nextProps.imageBase64 ||
    prevProps.width !== nextProps.width ||
    prevProps.height !== nextProps.height ||
    prevProps.cornerRadius !== nextProps.cornerRadius ||
    prevProps.borderWidth !== nextProps.borderWidth ||
    prevProps.title !== nextProps.title ||
    prevProps.description !== nextProps.description ||
    prevProps.draggable !== nextProps.draggable ||
    prevProps.opacity !== nextProps.opacity ||
    prevProps.rotation !== nextProps.rotation ||
    prevProps.zIndex !== nextProps.zIndex ||
    prevProps.clusteringEnabled !== nextProps.clusteringEnabled ||
    prevProps.animation !== nextProps.animation
  ) {
    return false;
  }

  if (
    prevProps.coordinate?.latitude !== nextProps.coordinate?.latitude ||
    prevProps.coordinate?.longitude !== nextProps.coordinate?.longitude
  ) {
    return false;
  }

  if (
    prevProps.anchor?.x !== nextProps.anchor?.x ||
    prevProps.anchor?.y !== nextProps.anchor?.y
  ) {
    return false;
  }

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

  if (!compareColors(prevProps.borderColor, nextProps.borderColor)) {
    return false;
  }

  return true;
};

/**
 * ImageMarker - Display images as map markers
 *
 * @example With URL
 * ```tsx
 * <ImageMarker
 *   coordinate={{ latitude: 41.29, longitude: 69.24 }}
 *   imageUrl="https://example.com/image.jpg"
 *   width={60}
 *   height={60}
 * />
 * ```
 *
 * @example With Base64 and styling
 * ```tsx
 * <ImageMarker
 *   coordinate={{ latitude: 41.30, longitude: 69.25 }}
 *   imageBase64={base64Data}
 *   width={50}
 *   height={50}
 *   cornerRadius={25}
 *   borderWidth={2}
 *   borderColor={Colors.white}
 * />
 * ```
 */
export const ImageMarker = memo(function ImageMarker({
  // Required
  coordinate,

  // Identification
  id,

  // Image-specific props
  imageUrl,
  imageBase64,
  width = 50,
  height = 50,
  cornerRadius = 8,
  borderWidth = 0,
  borderColor,

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
}: ImageMarkerProps) {
  // Build marker config

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
      config: {
        style: 'image' as const,
        image: {
          imageUrl,
          imageBase64,
          width,
          height,
          cornerRadius,
          borderWidth,
          borderColor: parseColor(borderColor) ?? Colors.gray,
        },
      },
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
      imageUrl,
      imageBase64,
      width,
      height,
      cornerRadius,
      borderWidth,
      borderColor,
      animation,
    ]
  );

  // Use shared marker hook
  useNitroMarker({
    idPrefix: 'image_marker',
    providedId: id,
    handlers,
    buildMarkerData,
  });

  return null;
}, arePropsEqual);

export default ImageMarker;
