const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = withMetroConfig(getDefaultConfig(__dirname), {
  root,
  dirname: __dirname,
});

// Use source files directly during development (enables Fast Refresh)
config.resolver.resolveRequest = (context, moduleName, platform) => {
  // Redirect package imports to source
  if (moduleName === 'react-native-nitro-map') {
    return {
      filePath: path.resolve(root, 'src/index.tsx'),
      type: 'sourceFile',
    };
  }

  // Handle internal config JSON require (from source files)
  if (
    moduleName ===
    'react-native-nitro-map/nitrogen/generated/shared/json/NitroMapConfig.json'
  ) {
    return {
      filePath: path.resolve(
        root,
        'nitrogen/generated/shared/json/NitroMapConfig.json'
      ),
      type: 'sourceFile',
    };
  }

  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
