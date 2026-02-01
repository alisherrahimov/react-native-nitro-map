// ============ Color Helpers ============

import type { MarkerColor } from '../types/marker';

/**
 * Color value that can be either a MarkerColor object or a hex string
 * Hex strings can be in formats: "#RRGGBB", "RRGGBB", "#RGB", or "RGB"
 * @example
 * ```ts
 * const color1: ColorValue = "#FF0000";        // Hex string
 * const color2: ColorValue = "#F00";           // Short hex
 * const color3: ColorValue = { r: 255, g: 0, b: 0, a: 255 }; // MarkerColor
 * ```
 */
export type ColorValue = MarkerColor | string;

/**
 * Parse a ColorValue into a MarkerColor object
 * Handles both hex strings and MarkerColor objects
 * @param color - Color value (hex string or MarkerColor)
 * @param defaultAlpha - Default alpha value (0-255) for hex strings
 * @returns MarkerColor object
 * @internal
 */
export const parseColor = (
  color: ColorValue | undefined,
  defaultAlpha: number = 255
): MarkerColor | undefined => {
  if (color === undefined) {
    return undefined;
  }

  // If it's already a MarkerColor object, return as-is
  if (
    typeof color === 'object' &&
    'r' in color &&
    'g' in color &&
    'b' in color
  ) {
    return {
      r: color.r,
      g: color.g,
      b: color.b,
      a: color.a ?? defaultAlpha,
    };
  }

  // It's a string - parse as hex
  if (typeof color === 'string') {
    return hex(color, defaultAlpha);
  }

  return undefined;
};

/**
 * Parse a ColorValue with a fallback default color
 * @param color - Color value (hex string or MarkerColor)
 * @param fallback - Fallback MarkerColor if parsing fails
 * @returns MarkerColor object
 * @internal
 */
export const parseColorWithFallback = (
  color: ColorValue | undefined,
  fallback: MarkerColor
): MarkerColor => {
  const parsed = parseColor(color);
  return parsed ?? fallback;
};

/**
 * Create a MarkerColor from RGB values
 * @param r - Red component (0-255)
 * @param g - Green component (0-255)
 * @param b - Blue component (0-255)
 * @param a - Alpha/opacity (0-255, default: 255)
 * @returns MarkerColor object
 * @example
 * ```ts
 * const customRed = rgb(255, 0, 0);
 * const semiTransparent = rgb(0, 0, 255, 128);
 * ```
 */
export const rgb = (
  r: number,
  g: number,
  b: number,
  a: number = 255
): MarkerColor => ({
  r,
  g,
  b,
  a,
});

/**
 * Create a MarkerColor from a hex string
 * @param hexStr - Hex color string (e.g., "#FF0000", "FF0000", "#F00", or "F00")
 * @param alpha - Alpha/opacity (0-255, default: 255)
 * @returns MarkerColor object
 * @example
 * ```ts
 * const red = hex("#FF0000");
 * const shortRed = hex("#F00");
 * const semiTransparentBlue = hex("#0000FF", 128);
 * ```
 */
export const hex = (hexStr: string, alpha: number = 255): MarkerColor => {
  // Try 6-char hex first (#RRGGBB or RRGGBB)
  const result6 = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hexStr);
  if (result6) {
    return {
      r: parseInt(result6[1]!, 16),
      g: parseInt(result6[2]!, 16),
      b: parseInt(result6[3]!, 16),
      a: alpha,
    };
  }

  // Try 3-char hex (#RGB or RGB)
  const result3 = /^#?([a-f\d])([a-f\d])([a-f\d])$/i.exec(hexStr);
  if (result3) {
    return {
      r: parseInt(result3[1]! + result3[1]!, 16),
      g: parseInt(result3[2]! + result3[2]!, 16),
      b: parseInt(result3[3]! + result3[3]!, 16),
      a: alpha,
    };
  }

  // Fallback to black
  return { r: 0, g: 0, b: 0, a: alpha };
};

/**
 * Preset colors for convenience
 * @example
 * ```ts
 * <NitroMarker backgroundColor={Colors.red} />
 * ```
 */
export const Colors = {
  /** White (255, 255, 255) */
  white: rgb(255, 255, 255),
  /** Black (0, 0, 0) */
  black: rgb(0, 0, 0),
  /** iOS system red (255, 59, 48) */
  red: rgb(255, 59, 48),
  /** iOS system blue (0, 122, 255) */
  blue: rgb(0, 122, 255),
  /** Material green (76, 175, 80) */
  green: rgb(76, 175, 80),
  /** iOS system orange (255, 149, 0) */
  orange: rgb(255, 149, 0),
  /** Dark gray (51, 51, 51) */
  gray: rgb(51, 51, 51),
  /** Light gray (240, 240, 240) */
  lightGray: rgb(240, 240, 240),
};
