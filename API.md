# @maydongroup/react-native-nitro-map

A high-performance multi-provider maps library for React Native, built with [Nitro Modules](https://github.com/margelo/react-native-nitro) for native speed.

## Installation

```bash
# npm
npm install @maydongroup/react-native-nitro-map

# yarn
yarn add @maydongroup/react-native-nitro-map
```

> [!NOTE]
> This is a private package. You need to configure `.npmrc` with your GitHub PAT token.

---

## Initialization

Before using the map, you must initialize it with your API key. Call `NitroMapInitialize` once at app startup:

```tsx
import {
  NitroMapInitialize,
  IsNitroMapInitialized,
} from '@maydongroup/react-native-nitro-map';

// Initialize in your app entry point (e.g., App.tsx or index.js)
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

> [!IMPORTANT]
> You must call `NitroMapInitialize` before rendering any `NitroMap` component.

---

## Quick Start

```tsx
import {
  NitroMap,
  NitroMapInitialize,
  PriceMarker,
  ImageMarker,
} from '@maydongroup/react-native-nitro-map';
import { useEffect } from 'react';

// Initialize once at app startup
NitroMapInitialize('YOUR_API_KEY', 'google');

function App() {
  return (
    <NitroMap
      provider="google"
      initialRegion={{
        latitude: 41.299496,
        longitude: 69.240073,
        latitudeDelta: 0.0922,
        longitudeDelta: 0.0421,
      }}
    >
      <PriceMarker
        coordinate={{ latitude: 41.299496, longitude: 69.240073 }}
        price="150K"
        currency="UZS"
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

---

## NitroMap Component

### Props

| Prop                    | Type                                    | Default      | Description                                  |
| ----------------------- | --------------------------------------- | ------------ | -------------------------------------------- |
| `provider`              | `'google' \| 'apple' \| 'yandex'`       | `'google'`   | Map provider to use. Apple Maps is iOS only. |
| `initialRegion`         | `Region`                                | -            | Initial map region to display                |
| `showsUserLocation`     | `boolean`                               | `false`      | Show user's current location on map          |
| `zoomEnabled`           | `boolean`                               | `true`       | Enable pinch-to-zoom gesture                 |
| `scrollEnabled`         | `boolean`                               | `true`       | Enable scroll/pan gesture                    |
| `rotateEnabled`         | `boolean`                               | `true`       | Enable rotation gesture                      |
| `pitchEnabled`          | `boolean`                               | `true`       | Enable 3D tilt gesture                       |
| `mapType`               | `'standard' \| 'satellite' \| 'hybrid'` | `'standard'` | Map display type                             |
| `customMapStyle`        | `MapStyle`                              | -            | Custom JSON styling for the map              |
| `showsMyLocationButton` | `boolean`                               | `true`       | Show "my location" button                    |
| `clusterConfig`         | `ClusterConfig`                         | -            | Marker clustering configuration              |
| `darkMode`              | `boolean`                               | `false`      | Enable dark mode styling                     |

### Event Callbacks

| Callback                 | Parameters                           | Description                              |
| ------------------------ | ------------------------------------ | ---------------------------------------- |
| `onMapReady`             | `() => void`                         | Called when the map is fully loaded      |
| `onPress`                | `(event: MapPressEvent) => void`     | Called when user taps on the map         |
| `onLongPress`            | `(event: MapPressEvent) => void`     | Called when user long-presses on the map |
| `onRegionChange`         | `(event: RegionChangeEvent) => void` | Called during region change              |
| `onRegionChangeComplete` | `(event: RegionChangeEvent) => void` | Called after region change completes     |
| `onMarkerPress`          | `(event: MarkerPressEvent) => void`  | Called when any marker is pressed        |
| `onMarkerDragStart`      | `(event: MarkerDragEvent) => void`   | Called when marker drag begins           |
| `onMarkerDrag`           | `(event: MarkerDragEvent) => void`   | Called during marker drag                |
| `onMarkerDragEnd`        | `(event: MarkerDragEvent) => void`   | Called when marker drag ends             |
| `onClusterPress`         | `(event: ClusterPressEvent) => void` | Called when a cluster is tapped          |

### Ref Methods

Access methods via `ref`:

```tsx
const mapRef = useRef<NitroMapRef>(null);

<NitroMap ref={mapRef} ... />

// Use methods
mapRef.current?.animateToRegion(region, 1000);
```

| Method                 | Parameters                                                                   | Return                   | Description                     |
| ---------------------- | ---------------------------------------------------------------------------- | ------------------------ | ------------------------------- |
| `animateToRegion`      | `(region: Region, duration?: number)`                                        | `void`                   | Animate to a region             |
| `fitToCoordinates`     | `(coordinates: Coordinate[], edgePadding?: EdgePadding, animated?: boolean)` | `void`                   | Fit map to show all coordinates |
| `animateCamera`        | `(camera: Camera, duration?: number)`                                        | `void`                   | Animate camera to position      |
| `getCamera`            | `()`                                                                         | `Promise<Camera>`        | Get current camera state        |
| `setCamera`            | `(camera: Camera)`                                                           | `void`                   | Set camera position instantly   |
| `getMapBoundaries`     | `()`                                                                         | `Promise<MapBoundaries>` | Get visible map boundaries      |
| `setMapStyle`          | `(style?: MapStyle)`                                                         | `void`                   | Apply custom map style          |
| `setIsDarkMode`        | `(enabled: boolean)`                                                         | `void`                   | Toggle dark mode                |
| `addMarker`            | `(marker: MarkerData)`                                                       | `void`                   | Add a single marker             |
| `addMarkers`           | `(markers: MarkerData[])`                                                    | `void`                   | Add multiple markers at once    |
| `updateMarker`         | `(marker: MarkerData)`                                                       | `void`                   | Update an existing marker       |
| `removeMarker`         | `(id: string)`                                                               | `void`                   | Remove marker by ID             |
| `selectMarker`         | `(id: string)`                                                               | `void`                   | Select/highlight a marker       |
| `clearMarkers`         | `()`                                                                         | `void`                   | Remove all markers              |
| `setClusteringEnabled` | `(enabled: boolean)`                                                         | `void`                   | Toggle marker clustering        |
| `refreshClusters`      | `()`                                                                         | `void`                   | Force cluster recalculation     |

---

## PriceMarker Component

Display price tags on the map. Supports both simple price tags and full-featured markers with currency.

### Props

| Prop                      | Type                          | Default              | Description                               |
| ------------------------- | ----------------------------- | -------------------- | ----------------------------------------- |
| `coordinate`              | `Coordinate`                  | **required**         | Marker position `{ latitude, longitude }` |
| `price`                   | `string`                      | **required**         | Price text (e.g., "150K", "9M")           |
| `id`                      | `string`                      | auto-generated       | Unique identifier for the marker          |
| `currency`                | `string`                      | -                    | Currency code (e.g., "UZS", "USD")        |
| `selected`                | `boolean`                     | `false`              | Selected state (changes colors)           |
| `backgroundColor`         | `MarkerColor`                 | white                | Background color                          |
| `selectedBackgroundColor` | `MarkerColor`                 | -                    | Background when selected                  |
| `textColor`               | `MarkerColor`                 | black                | Text color                                |
| `selectedTextColor`       | `MarkerColor`                 | -                    | Text color when selected                  |
| `fontSize`                | `number`                      | `14`                 | Font size in pixels                       |
| `paddingHorizontal`       | `number`                      | -                    | Horizontal padding                        |
| `paddingVertical`         | `number`                      | -                    | Vertical padding                          |
| `shadowOpacity`           | `number`                      | -                    | Shadow opacity (0-1)                      |
| `title`                   | `string`                      | -                    | Info window title                         |
| `description`             | `string`                      | -                    | Info window description                   |
| `draggable`               | `boolean`                     | `false`              | Allow drag interaction                    |
| `opacity`                 | `number`                      | `1`                  | Marker opacity (0-1)                      |
| `rotation`                | `number`                      | `0`                  | Rotation in degrees                       |
| `zIndex`                  | `number`                      | `0`                  | Stack order for overlapping markers       |
| `anchor`                  | `Point`                       | `{ x: 0.5, y: 0.5 }` | Anchor point (0-1 range)                  |
| `clusteringEnabled`       | `boolean`                     | `true`               | Include in clustering                     |
| `animation`               | `'none' \| 'pop' \| 'fadeIn'` | `'none'`             | Appear animation                          |

### Event Callbacks

| Callback      | Parameters                         | Description                  |
| ------------- | ---------------------------------- | ---------------------------- |
| `onPress`     | `() => void`                       | Called when marker is tapped |
| `onDragStart` | `(coordinate: Coordinate) => void` | Called when drag begins      |
| `onDrag`      | `(coordinate: Coordinate) => void` | Called during drag           |
| `onDragEnd`   | `(coordinate: Coordinate) => void` | Called when drag ends        |

### Example

```tsx
<PriceMarker
  coordinate={{ latitude: 41.299496, longitude: 69.240073 }}
  price="9M"
  currency="UZS"
  selected={isSelected}
  backgroundColor={Colors.white}
  selectedBackgroundColor={Colors.red}
  onPress={() => setSelected(true)}
/>
```

---

## ImageMarker Component

Display images as map markers with customizable styling.

### Props

| Prop                | Type                          | Default              | Description                               |
| ------------------- | ----------------------------- | -------------------- | ----------------------------------------- |
| `coordinate`        | `Coordinate`                  | **required**         | Marker position `{ latitude, longitude }` |
| `id`                | `string`                      | auto-generated       | Unique identifier for the marker          |
| `imageUrl`          | `string`                      | -                    | URL of the image to display               |
| `imageBase64`       | `string`                      | -                    | Base64-encoded image data                 |
| `width`             | `number`                      | `50`                 | Image width in pixels                     |
| `height`            | `number`                      | `50`                 | Image height in pixels                    |
| `cornerRadius`      | `number`                      | `8`                  | Corner radius                             |
| `borderWidth`       | `number`                      | `0`                  | Border thickness                          |
| `borderColor`       | `MarkerColor`                 | gray                 | Border color                              |
| `title`             | `string`                      | -                    | Info window title                         |
| `description`       | `string`                      | -                    | Info window description                   |
| `draggable`         | `boolean`                     | `false`              | Allow drag interaction                    |
| `opacity`           | `number`                      | `1`                  | Marker opacity (0-1)                      |
| `rotation`          | `number`                      | `0`                  | Rotation in degrees                       |
| `zIndex`            | `number`                      | `0`                  | Stack order for overlapping markers       |
| `anchor`            | `Point`                       | `{ x: 0.5, y: 0.5 }` | Anchor point (0-1 range)                  |
| `clusteringEnabled` | `boolean`                     | `true`               | Include in clustering                     |
| `animation`         | `'none' \| 'pop' \| 'fadeIn'` | `'none'`             | Appear animation                          |

### Event Callbacks

| Callback      | Parameters                         | Description                  |
| ------------- | ---------------------------------- | ---------------------------- |
| `onPress`     | `() => void`                       | Called when marker is tapped |
| `onDragStart` | `(coordinate: Coordinate) => void` | Called when drag begins      |
| `onDrag`      | `(coordinate: Coordinate) => void` | Called during drag           |
| `onDragEnd`   | `(coordinate: Coordinate) => void` | Called when drag ends        |

### Example

```tsx
<ImageMarker
  coordinate={{ latitude: 41.299496, longitude: 69.240073 }}
  imageUrl="https://example.com/avatar.jpg"
  width={50}
  height={50}
  cornerRadius={25}
  borderWidth={2}
  borderColor={Colors.white}
/>
```

---

## Types Reference

### Region

```ts
type Region = {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
};
```

### Coordinate

```ts
type Coordinate = {
  latitude: number;
  longitude: number;
};
```

### Camera

```ts
type Camera = {
  center: Coordinate;
  pitch: number; // Tilt angle (0-90)
  heading: number; // Rotation in degrees
  altitude: number; // Altitude in meters
  zoom: number; // Zoom level
};
```

### EdgePadding

```ts
type EdgePadding = {
  top: number;
  right: number;
  bottom: number;
  left: number;
};
```

### MapBoundaries

```ts
type MapBoundaries = {
  northEast: Coordinate;
  southWest: Coordinate;
};
```

### MarkerColor

```ts
type MarkerColor = {
  r: number; // 0-255
  g: number; // 0-255
  b: number; // 0-255
  a: number; // 0-255 (alpha)
};
```

### MarkerStyle

```ts
type MarkerStyle = 'default' | 'image' | 'priceMarker';
```

### MarkerAnimation

```ts
type MarkerAnimation = 'none' | 'pop' | 'fadeIn';
```

### ClusterConfig

```ts
type ClusterConfig = {
  enabled: boolean;
  minimumClusterSize: number;
  maxZoom: number;
  backgroundColor: MarkerColor;
  textColor: MarkerColor;
  borderWidth: number;
  borderColor: MarkerColor;
  animatesClusters: boolean;
  animationDuration: number; // in seconds
  animationStyle: 'default' | 'bounce' | 'scale' | 'fade' | 'spring';
};
```

### Event Types

```ts
type MapPressEvent = {
  coordinate: Coordinate;
  position: Point; // Screen position { x, y }
};

type RegionChangeEvent = {
  region: Region;
  isGesture: boolean;
};

type MarkerPressEvent = {
  id: string;
  coordinate: Coordinate;
};

type MarkerDragEvent = {
  id: string;
  coordinate: Coordinate;
};

type ClusterPressEvent = {
  coordinate: Coordinate;
  markerIds: string[];
  count: number;
};
```

---

## Color Helpers

```tsx
import { rgb, hex, Colors } from '@maydongroup/react-native-nitro-map';

// Create color from RGB values
const myColor = rgb(255, 100, 50);

// Create color with alpha
const transparentBlue = rgb(0, 0, 255, 128);

// Create color from hex string
const hexColor = hex('#FF6432');

// Preset colors
Colors.white; // rgb(255, 255, 255)
Colors.black; // rgb(0, 0, 0)
Colors.red; // rgb(255, 59, 48)
Colors.blue; // rgb(0, 122, 255)
Colors.green; // rgb(76, 175, 80)
Colors.orange; // rgb(255, 149, 0)
Colors.gray; // rgb(51, 51, 51)
Colors.lightGray; // rgb(240, 240, 240)
```

---

## Examples

### Price Markers with Selection

```tsx
const [selectedId, setSelectedId] = useState<string | null>(null);

{
  properties.map((p) => (
    <PriceMarker
      key={p.id}
      id={p.id}
      coordinate={p.coordinate}
      price={p.price}
      currency="UZS"
      selected={selectedId === p.id}
      onPress={() => setSelectedId(p.id)}
    />
  ));
}
```

### Image Markers

```tsx
<ImageMarker
  coordinate={{ latitude: 41.299496, longitude: 69.240073 }}
  imageUrl="https://example.com/avatar.jpg"
  width={60}
  height={60}
  cornerRadius={30}
  borderWidth={3}
  borderColor={Colors.white}
/>
```

### Clustered Markers

```tsx
<NitroMap
  clusterConfig={{
    enabled: true,
    minimumClusterSize: 3,
    maxZoom: 15,
    backgroundColor: Colors.blue,
    textColor: Colors.white,
    borderWidth: 2,
    borderColor: Colors.white,
    animatesClusters: true,
    animationDuration: 0.3,
    animationStyle: 'spring',
  }}
>
  {markers.map((m) => (
    <PriceMarker
      key={m.id}
      id={m.id}
      coordinate={m.coordinate}
      price={m.price}
      clusteringEnabled={true}
    />
  ))}
</NitroMap>
```

### Draggable Markers

```tsx
const [position, setPosition] = useState({
  latitude: 41.299496,
  longitude: 69.240073,
});

<PriceMarker
  coordinate={position}
  price="Drag me"
  draggable
  animation="pop"
  onDragStart={(coord) => console.log('Started at', coord)}
  onDragEnd={(coord) => setPosition(coord)}
/>;
```

---

## License

MIT © [maydongroup](https://github.com/maydongroup)
