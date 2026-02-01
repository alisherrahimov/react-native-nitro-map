# react-native-nitro-map

> ⚠️ **BETA - Work in Progress**
>
> This library is currently in **active development** and **beta testing**. APIs may change without notice. **Do not use in production** until a stable release is announced.

A high-performance **multi-provider** maps library for React Native, built with [Nitro Modules](https://nitro.margelo.com/) for native speed.

## ✨ Features

- 🚀 **Native Performance** - Built with Nitro Modules for maximum speed
- 🗺️ **Multi-Provider** - Apple Maps, Google Maps, and Yandex Maps support
- 📍 **High-Performance Clustering** - C++ clustering engine for 30,000+ markers
- 🎨 **Customizable Markers** - Price and Image marker styles
- 🌙 **Dark Mode Support** - Built-in dark theme
- 📱 **iOS & Android** - Full platform support

## Supported Providers

| Provider        | iOS        | Android | Notes               |
| --------------- | ---------- | ------- | ------------------- |
| **Apple Maps**  | ✅ iOS 17+ | ❌      | No API key required |
| **Google Maps** | ✅         | ✅      | Requires API key    |
| **Yandex Maps** | ✅         | ✅      | Requires API key    |

## Installation

```bash
npm install react-native-nitro-map react-native-nitro-modules
# or
yarn add react-native-nitro-map react-native-nitro-modules
```

### iOS Setup

```bash
cd ios && pod install
```

### Android Setup

#### Google Maps

Add your Google Maps API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
  <meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
</application>
```

#### Yandex Maps

Add your Yandex Maps API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
  <meta-data
    android:name="com.yandex.android.mapkit.ApiKey"
    android:value="YOUR_YANDEX_MAPS_API_KEY"/>
</application>
```

## Initialization

Before using the map, you must initialize it with your API key:

```tsx
import {
  NitroMapInitialize,
  IsNitroMapInitialized,
} from 'react-native-nitro-map';

// Initialize once at app startup
// Google Maps
NitroMapInitialize('YOUR_GOOGLE_MAPS_API_KEY', 'google');

// OR Yandex Maps
NitroMapInitialize('YOUR_YANDEX_MAPS_API_KEY', 'yandex');

// OR Apple Maps (no API key required)
NitroMapInitialize('', 'apple');

// Check if initialized
if (IsNitroMapInitialized()) {
  console.log('Map is ready!');
}
```

> **Important**: You must call `NitroMapInitialize` before rendering any `NitroMap` component.

## Quick Start

```tsx
import {
  NitroMap,
  NitroMapInitialize,
  PriceMarker,
  ImageMarker,
} from 'react-native-nitro-map';

// Initialize once at app startup
NitroMapInitialize('YOUR_API_KEY', 'google');

export default function App() {
  return (
    <NitroMap
      provider="google" // "google" | "apple" | "yandex"
      initialRegion={{
        latitude: 41.2995,
        longitude: 69.2401,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05,
      }}
    >
      <PriceMarker
        coordinate={{ latitude: 41.2995, longitude: 69.2401 }}
        price="150K"
        currency="USD"
      />
      <ImageMarker
        coordinate={{ latitude: 41.305, longitude: 69.245 }}
        imageUrl="https://example.com/avatar.jpg"
        width={50}
        height={50}
      />
    </NitroMap>
  );
}
```

## Provider Selection

Choose your map provider based on your needs:

```tsx
// Apple Maps - No API key, iOS 17+ only
<NitroMap provider="apple" />

// Google Maps - Requires API key, best coverage
<NitroMap provider="google" />

// Yandex Maps - Requires API key, best for CIS regions
<NitroMap provider="yandex" />
```

| Feature              | Apple  | Google | Yandex              |
| -------------------- | ------ | ------ | ------------------- |
| API Key Required     | ❌     | ✅     | ✅                  |
| Satellite View       | ✅     | ✅     | ⚠️ Needs permission |
| Clustering Engine    | C++    | C++    | C++                 |
| Min iOS Version      | 17.0   | 12.0   | 12.0                |
| Max Markers (tested) | 30,000 | 30,000 | 30,000              |

## NitroMap Props

| Prop                    | Type                                    | Default      | Description                |
| ----------------------- | --------------------------------------- | ------------ | -------------------------- |
| `provider`              | `'google' \| 'apple' \| 'yandex'`       | `'google'`   | Map provider               |
| `initialRegion`         | `Region`                                | -            | Initial map region         |
| `showsUserLocation`     | `boolean`                               | `false`      | Show user location dot     |
| `showsMyLocationButton` | `boolean`                               | `false`      | Show location button       |
| `mapType`               | `'standard' \| 'satellite' \| 'hybrid'` | `'standard'` | Map style                  |
| `darkMode`              | `boolean`                               | `false`      | Enable dark theme          |
| `zoomEnabled`           | `boolean`                               | `true`       | Allow zoom gestures        |
| `scrollEnabled`         | `boolean`                               | `true`       | Allow scroll gestures      |
| `rotateEnabled`         | `boolean`                               | `true`       | Allow rotation gestures    |
| `pitchEnabled`          | `boolean`                               | `true`       | Allow pitch/tilt gestures  |
| `clusterConfig`         | `ClusterConfig`                         | -            | Marker clustering settings |

### Events

| Prop                     | Type                                 | Description          |
| ------------------------ | ------------------------------------ | -------------------- |
| `onMapReady`             | `() => void`                         | Map finished loading |
| `onPress`                | `(event: MapPressEvent) => void`     | Map tap              |
| `onLongPress`            | `(event: MapPressEvent) => void`     | Map long press       |
| `onRegionChange`         | `(event: RegionChangeEvent) => void` | Region changing      |
| `onRegionChangeComplete` | `(event: RegionChangeEvent) => void` | Region change ended  |
| `onMarkerPress`          | `(event: MarkerPressEvent) => void`  | Any marker tapped    |
| `onClusterPress`         | `(event: ClusterPressEvent) => void` | Cluster tapped       |

## NitroMap Methods

Access methods via ref:

```tsx
const mapRef = useRef<NitroMapRef>(null);

// Animate to region
mapRef.current?.animateToRegion(
  {
    latitude: 41.2995,
    longitude: 69.2401,
    latitudeDelta: 0.01,
    longitudeDelta: 0.01,
  },
  500
);

// Select marker (changes color, no React re-render!)
mapRef.current?.selectMarker('marker-id');

// Fit to coordinates
mapRef.current?.fitToCoordinates(
  [
    { latitude: 41.299, longitude: 69.24 },
    { latitude: 41.31, longitude: 69.25 },
  ],
  { top: 50, bottom: 50, left: 50, right: 50 },
  true
);

// Get camera
const camera = await mapRef.current?.getCamera();

// Get boundaries
const bounds = await mapRef.current?.getMapBoundaries();
```

| Method                                          | Description                    |
| ----------------------------------------------- | ------------------------------ |
| `animateToRegion(region, duration?)`            | Animate camera to region       |
| `fitToCoordinates(coords, padding?, animated?)` | Fit map to coordinates         |
| `animateCamera(camera, duration?)`              | Animate to camera position     |
| `setCamera(camera)`                             | Set camera immediately         |
| `getCamera()`                                   | Get current camera             |
| `getMapBoundaries()`                            | Get visible region bounds      |
| `addMarker(marker)`                             | Add marker programmatically    |
| `addMarkers(markers)`                           | Add multiple markers           |
| `updateMarker(marker)`                          | Update existing marker         |
| `removeMarker(id)`                              | Remove marker by ID            |
| `clearMarkers()`                                | Remove all markers             |
| `selectMarker(id)`                              | Select marker (native styling) |
| `setClusteringEnabled(enabled)`                 | Toggle clustering              |
| `refreshClusters()`                             | Force clustering refresh       |

## PriceMarker Component

Display price tags on the map with **zero re-render selection**:

```tsx
import { PriceMarker, Colors } from 'react-native-nitro-map';

<PriceMarker
  coordinate={{ latitude: 41.2995, longitude: 69.2401 }}
  price="150K"
  currency="USD"
  selected={false}
  backgroundColor={Colors.white}
  selectedBackgroundColor={Colors.red}
  textColor={Colors.black}
  selectedTextColor={Colors.white}
  fontSize={14}
  onPress={() => console.log('Pressed!')}
/>;
```

### PriceMarker Props

| Prop                      | Type          | Default            | Description               |
| ------------------------- | ------------- | ------------------ | ------------------------- |
| `coordinate`              | `Coordinate`  | **Required**       | Marker position           |
| `price`                   | `string`      | **Required**       | Price text (e.g., "150K") |
| `id`                      | `string`      | auto-generated     | Unique identifier         |
| `currency`                | `string`      | -                  | Currency code             |
| `selected`                | `boolean`     | `false`            | Selected state            |
| `backgroundColor`         | `MarkerColor` | white              | Background color          |
| `selectedBackgroundColor` | `MarkerColor` | -                  | Background when selected  |
| `textColor`               | `MarkerColor` | black              | Text color                |
| `selectedTextColor`       | `MarkerColor` | -                  | Text color when selected  |
| `fontSize`                | `number`      | `14`               | Font size in pixels       |
| `paddingHorizontal`       | `number`      | -                  | Horizontal padding        |
| `paddingVertical`         | `number`      | -                  | Vertical padding          |
| `shadowOpacity`           | `number`      | -                  | Shadow opacity (0-1)      |
| `draggable`               | `boolean`     | `false`            | Allow dragging            |
| `opacity`                 | `number`      | `1`                | Marker opacity (0-1)      |
| `anchor`                  | `Point`       | `{x: 0.5, y: 0.5}` | Anchor point              |
| `clusteringEnabled`       | `boolean`     | `true`             | Include in clustering     |
| `animation`               | `string`      | `'none'`           | Appear animation          |

## ImageMarker Component

Display images as map markers:

```tsx
import { ImageMarker, Colors } from 'react-native-nitro-map';

<ImageMarker
  coordinate={{ latitude: 41.2995, longitude: 69.2401 }}
  imageUrl="https://example.com/avatar.jpg"
  width={50}
  height={50}
  cornerRadius={25}
  borderWidth={2}
  borderColor={Colors.white}
/>;
```

### ImageMarker Props

| Prop                | Type          | Default            | Description            |
| ------------------- | ------------- | ------------------ | ---------------------- |
| `coordinate`        | `Coordinate`  | **Required**       | Marker position        |
| `id`                | `string`      | auto-generated     | Unique identifier      |
| `imageUrl`          | `string`      | -                  | URL of the image       |
| `imageBase64`       | `string`      | -                  | Base64-encoded image   |
| `width`             | `number`      | `50`               | Image width in pixels  |
| `height`            | `number`      | `50`               | Image height in pixels |
| `cornerRadius`      | `number`      | `8`                | Corner radius          |
| `borderWidth`       | `number`      | `0`                | Border thickness       |
| `borderColor`       | `MarkerColor` | gray               | Border color           |
| `draggable`         | `boolean`     | `false`            | Allow dragging         |
| `opacity`           | `number`      | `1`                | Marker opacity (0-1)   |
| `anchor`            | `Point`       | `{x: 0.5, y: 0.5}` | Anchor point           |
| `clusteringEnabled` | `boolean`     | `true`             | Include in clustering  |
| `animation`         | `string`      | `'none'`           | Appear animation       |

### Marker Events

| Prop          | Type              | Description   |
| ------------- | ----------------- | ------------- |
| `onPress`     | `() => void`      | Marker tapped |
| `onDragStart` | `(coord) => void` | Drag started  |
| `onDrag`      | `(coord) => void` | Dragging      |
| `onDragEnd`   | `(coord) => void` | Drag ended    |

## Selection Example

```tsx
const MARKERS = [
  { id: 'marker-1', latitude: 41.29, longitude: 69.24, price: '100K' },
  { id: 'marker-2', latitude: 41.3, longitude: 69.25, price: '150K' },
];

function App() {
  const mapRef = useRef<NitroMapRef>(null);

  const onMarkerPress = useCallback((event: MarkerPressEvent) => {
    // Native handles selection styling - ZERO React re-renders!
    mapRef.current?.selectMarker(event.id);

    // Optionally trigger other UI (bottom sheet, etc.)
    fetchMarkerDetails(event.id);
  }, []);

  return (
    <NitroMap ref={mapRef} onMarkerPress={onMarkerPress}>
      {MARKERS.map((m) => (
        <PriceMarker
          key={m.id}
          id={m.id}
          coordinate={{ latitude: m.latitude, longitude: m.longitude }}
          price={m.price}
          currency="USD"
          backgroundColor={Colors.white}
          selectedBackgroundColor={Colors.red}
          textColor={Colors.black}
          selectedTextColor={Colors.white}
        />
      ))}
    </NitroMap>
  );
}
```

## C++ Clustering Engine

All three providers use the same high-performance C++ clustering engine:

```tsx
<NitroMap
  clusterConfig={{
    enabled: true,
    minimumClusterSize: 2,
    maxZoom: 20, // Clusters break into markers above this zoom
    backgroundColor: { r: 255, g: 87, b: 51, a: 255 },
    textColor: { r: 255, g: 255, b: 255, a: 255 },
    borderWidth: 2,
    borderColor: { r: 255, g: 255, b: 255, a: 255 },
    animatesClusters: true,
    animationDuration: 0.3,
    animationStyle: 'default',
  }}
  onClusterPress={(event) => {
    console.log(`Cluster with ${event.count} markers`);
    console.log('Marker IDs:', event.markerIds);

    // Zoom into cluster
    mapRef.current?.animateToRegion({
      ...event.coordinate,
      latitudeDelta: 0.01,
      longitudeDelta: 0.01,
    });
  }}
>
  {markers.map((m) => (
    <PriceMarker key={m.id} {...m} clusteringEnabled={true} />
  ))}
</NitroMap>
```

### Performance

| Markers | Apple      | Google     | Yandex     |
| ------- | ---------- | ---------- | ---------- |
| 100     | ⚡ Instant | ⚡ Instant | ⚡ Instant |
| 1,000   | ⚡ Fast    | ⚡ Fast    | ⚡ Fast    |
| 10,000  | ✅ Smooth  | ✅ Smooth  | ✅ Smooth  |
| 30,000  | ✅ Works   | ✅ Works   | ✅ Works   |

## Color Helpers

```tsx
import { rgb, hex, Colors } from 'react-native-nitro-map';

// RGB helper
const red = rgb(255, 0, 0); // { r: 255, g: 0, b: 0, a: 255 }
const semiRed = rgb(255, 0, 0, 128); // 50% opacity

// Hex helper
const blue = hex('#0000FF');
const semiBlue = hex('#0000FF', 128);

// Preset colors
Colors.red; // { r: 255, g: 59, b: 48, a: 255 }
Colors.blue; // { r: 0, g: 122, b: 255, a: 255 }
Colors.green; // { r: 76, g: 175, b: 80, a: 255 }
Colors.white; // { r: 255, g: 255, b: 255, a: 255 }
Colors.black; // { r: 0, g: 0, b: 0, a: 255 }
```

## Types

```typescript
type Region = {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
};

type Coordinate = {
  latitude: number;
  longitude: number;
};

type Camera = {
  center: Coordinate;
  pitch: number;
  heading: number;
  altitude: number;
  zoom: number;
};

type MarkerColor = {
  r: number; // 0-255
  g: number; // 0-255
  b: number; // 0-255
  a: number; // 0-255
};

type MapProvider = 'google' | 'apple' | 'yandex';
type MapType = 'standard' | 'satellite' | 'hybrid';
type MarkerStyle = 'default' | 'image' | 'priceMarker';
type MarkerAnimation = 'none' | 'pop' | 'fadeIn';
```

## Troubleshooting

### Apple Maps shows "+1 more" labels

This is MapKit's native clustering. Make sure you're using `provider="apple"` with the C++ clustering engine enabled.

### Yandex satellite mode shows "Forbidden"

Yandex satellite tiles require explicit permission in the Yandex Developer Console.

### Markers not appearing

1. Check that coordinates are within visible region
2. Verify marker `zIndex` if markers overlap
3. Ensure `clusteringEnabled` is set correctly

### Performance issues with many markers

1. Enable clustering: `clusterConfig={{ enabled: true }}`
2. Use `addMarkers()` for batch adding instead of individual `addMarker()` calls
3. Consider reducing `maxZoom` to keep more markers clustered

## License

MIT

---

Made with [Nitro Modules](https://nitro.margelo.com/)
