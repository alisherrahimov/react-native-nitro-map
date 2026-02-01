import { NitroModules } from 'react-native-nitro-modules';
import type { NitroMapConfig } from '../specs/NitroMapConfig.nitro';
import type { MapProvider } from '../types/map';

const NitroMapConfig =
  NitroModules.createHybridObject<NitroMapConfig>('NitroMapConfig');

// Store the default provider set during initialization
let defaultProvider: MapProvider = 'google';

export function NitroMapInitialize(
  apiKey: string,
  provider: MapProvider
): void {
  defaultProvider = provider;
  NitroMapConfig.NitroMapInitialize(apiKey, provider);
}

export function IsNitroMapInitialized(): boolean {
  return NitroMapConfig.IsNitroMapInitialized();
}

export function getDefaultProvider(): MapProvider {
  return defaultProvider;
}
