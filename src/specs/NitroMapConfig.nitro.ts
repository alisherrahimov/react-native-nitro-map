import { type HybridObject } from 'react-native-nitro-modules';
import type { MapProvider } from '../types/map';

export interface NitroMapConfig
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  NitroMapInitialize(apiKey: string, provider: MapProvider): void;
  IsNitroMapInitialized(): boolean;
}
