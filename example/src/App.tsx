import { useRef, useState, useMemo, useEffect, useCallback } from 'react';
import { StyleSheet, View, Text, ActivityIndicator } from 'react-native';

import NitroMap, {
  PriceMarker,
  type NitroMapRef,
  type ClusterPressEvent,
  type RegionChangeEvent,
  type MapBoundaries,
  NitroMapInitialize,
} from 'react-native-nitro-map';

// ============================================================================
// CONFIGURATION
// ============================================================================

// Debounce delay in milliseconds
const DEBOUNCE_DELAY = 300;

// ============================================================================
// MARKER GENERATION - 1000+ MARKERS AROUND TASHKENT
// ============================================================================

interface MarkerData {
  id: string;
  latitude: number;
  longitude: number;
  price: string;
}

// Price options for variety
const PRICE_OPTIONS = [
  '45K',
  '55K',
  '65K',
  '75K',
  '85K',
  '95K',
  '110K',
  '125K',
  '140K',
  '155K',
  '170K',
  '185K',
  '200K',
  '220K',
  '250K',
  '280K',
  '320K',
  '360K',
  '400K',
  '450K',
  '500K',
  '550K',
  '600K',
  '700K',
  '800K',
  '900K',
  '1M',
  '1.2M',
  '1.5M',
  '2M',
];

// Tashkent neighborhoods with their center coordinates and price multipliers
const NEIGHBORHOODS = [
  // Premium areas (center)
  {
    name: 'Tashkent City',
    lat: 41.318,
    lng: 69.2855,
    radius: 0.015,
    density: 80,
    priceBase: 25,
  },
  {
    name: 'Amir Timur',
    lat: 41.3111,
    lng: 69.2797,
    radius: 0.012,
    density: 60,
    priceBase: 22,
  },
  {
    name: 'Broadway',
    lat: 41.3089,
    lng: 69.2783,
    radius: 0.01,
    density: 50,
    priceBase: 20,
  },

  // High-end areas
  {
    name: 'Mirzo Ulugbek',
    lat: 41.3447,
    lng: 69.2867,
    radius: 0.025,
    density: 70,
    priceBase: 18,
  },
  {
    name: 'Yunusabad',
    lat: 41.355,
    lng: 69.265,
    radius: 0.03,
    density: 85,
    priceBase: 16,
  },
  {
    name: 'Minor',
    lat: 41.3494,
    lng: 69.2692,
    radius: 0.018,
    density: 55,
    priceBase: 17,
  },

  // Mid-range areas
  {
    name: 'Yakkasaray',
    lat: 41.2903,
    lng: 69.2683,
    radius: 0.025,
    density: 65,
    priceBase: 14,
  },
  {
    name: 'Mirabad',
    lat: 41.2978,
    lng: 69.2611,
    radius: 0.022,
    density: 60,
    priceBase: 15,
  },
  {
    name: 'Shaykhontohur',
    lat: 41.2997,
    lng: 69.2489,
    radius: 0.02,
    density: 50,
    priceBase: 12,
  },

  // Traditional areas
  {
    name: 'Chorsu',
    lat: 41.3268,
    lng: 69.2337,
    radius: 0.018,
    density: 55,
    priceBase: 8,
  },
  {
    name: 'Old City',
    lat: 41.329,
    lng: 69.238,
    radius: 0.015,
    density: 45,
    priceBase: 7,
  },
  {
    name: 'Almazar',
    lat: 41.33,
    lng: 69.21,
    radius: 0.028,
    density: 70,
    priceBase: 9,
  },

  // Residential suburbs
  {
    name: 'Chilanzar',
    lat: 41.288,
    lng: 69.205,
    radius: 0.035,
    density: 90,
    priceBase: 6,
  },
  {
    name: 'Sergeli',
    lat: 41.235,
    lng: 69.215,
    radius: 0.04,
    density: 85,
    priceBase: 4,
  },
  {
    name: 'Yashnabad',
    lat: 41.265,
    lng: 69.31,
    radius: 0.03,
    density: 65,
    priceBase: 5,
  },
  {
    name: 'Bektemir',
    lat: 41.215,
    lng: 69.325,
    radius: 0.035,
    density: 60,
    priceBase: 3,
  },
  {
    name: 'Uchtepa',
    lat: 41.305,
    lng: 69.19,
    radius: 0.03,
    density: 70,
    priceBase: 5,
  },
  {
    name: 'Olmazor',
    lat: 41.32,
    lng: 69.202,
    radius: 0.025,
    density: 55,
    priceBase: 6,
  },

  // Outer areas
  {
    name: 'Airport Area',
    lat: 41.2578,
    lng: 69.2812,
    radius: 0.025,
    density: 40,
    priceBase: 8,
  },
  {
    name: 'Magic City',
    lat: 41.322,
    lng: 69.315,
    radius: 0.02,
    density: 45,
    priceBase: 15,
  },
  {
    name: 'Botanical',
    lat: 41.338,
    lng: 69.335,
    radius: 0.022,
    density: 35,
    priceBase: 10,
  },

  // Additional dense areas to reach 1000+
  {
    name: 'Chilanzar West',
    lat: 41.275,
    lng: 69.185,
    radius: 0.03,
    density: 75,
    priceBase: 5,
  },
  {
    name: 'Yunusabad North',
    lat: 41.37,
    lng: 69.26,
    radius: 0.028,
    density: 70,
    priceBase: 12,
  },
  {
    name: 'Sergeli South',
    lat: 41.22,
    lng: 69.205,
    radius: 0.035,
    density: 65,
    priceBase: 3,
  },
  {
    name: 'Mirzo East',
    lat: 41.34,
    lng: 69.31,
    radius: 0.025,
    density: 55,
    priceBase: 11,
  },
];

// Seeded random number generator for consistent results
function seededRandom(seed: number): number {
  const x = Math.sin(seed * 9999) * 10000;
  return x - Math.floor(x);
}

// Generate all markers for Tashkent
function generateTashkentMarkers(): MarkerData[] {
  const markers: MarkerData[] = [];
  let globalIndex = 0;

  for (const neighborhood of NEIGHBORHOODS) {
    for (let i = 0; i < neighborhood.density; i++) {
      // Use seeded random for consistent marker placement
      const seed1 = globalIndex * 12345 + i * 67890;
      const seed2 = globalIndex * 67890 + i * 12345;

      // Random angle and distance from center
      const angle = seededRandom(seed1) * 2 * Math.PI;
      const distance = seededRandom(seed2) * neighborhood.radius;

      // Calculate position
      const lat = neighborhood.lat + Math.cos(angle) * distance;
      const lng = neighborhood.lng + Math.sin(angle) * distance * 1.3; // Adjust for longitude scale

      // Determine price based on neighborhood and random variation
      const priceVariation = Math.floor(seededRandom(seed1 + seed2) * 8) - 2;
      const priceIndex = Math.max(
        0,
        Math.min(
          PRICE_OPTIONS.length - 1,
          neighborhood.priceBase + priceVariation
        )
      );

      markers.push({
        id: `marker-${globalIndex}-${i}`,
        latitude: lat,
        longitude: lng,
        price: PRICE_OPTIONS[priceIndex]!,
      });

      globalIndex++;
    }
  }

  console.log(
    `🏠 Generated ${markers.length} markers across ${NEIGHBORHOODS.length} neighborhoods`
  );
  return markers;
}

// Pre-generate all markers once
const TASHKENT_MARKERS = generateTashkentMarkers();

// ============================================================================
// HOOKS
// ============================================================================

function useDebounce<T extends (...args: any[]) => void>(
  callback: T,
  delay: number
): T {
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const debouncedCallback = useCallback(
    (...args: Parameters<T>) => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      timeoutRef.current = setTimeout(() => {
        callback(...args);
      }, delay);
    },
    [callback, delay]
  ) as T;

  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return debouncedCallback;
}

// ============================================================================
// MAIN APP
// ============================================================================

export default function App() {
  const mapRef = useRef<NitroMapRef>(null);

  // State
  const [markers, setMarkers] = useState<MarkerData[]>([]);
  const [selectedMarkerId, setSelectedMarkerId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // Initialize map SDK
  useEffect(() => {
    NitroMapInitialize(process.env.GOOGLE_MAP!, 'google');
  }, []);

  // Filter markers within viewport bounds
  const filterMarkersInBounds = useCallback(
    (bounds: MapBoundaries): MarkerData[] => {
      const { northEast, southWest } = bounds;
      return TASHKENT_MARKERS.filter(
        (marker) =>
          marker.latitude >= southWest.latitude &&
          marker.latitude <= northEast.latitude &&
          marker.longitude >= southWest.longitude &&
          marker.longitude <= northEast.longitude
      );
    },
    []
  );

  // Load markers for current viewport
  const loadMarkersForViewport = useCallback(async () => {
    const bounds = await mapRef.current?.getMapBoundaries();
    if (!bounds) return;

    setIsLoading(true);

    const visibleMarkers = filterMarkersInBounds(bounds);
    setMarkers(visibleMarkers);

    console.log(
      `📍 Showing ${visibleMarkers.length} / ${TASHKENT_MARKERS.length} markers`
    );
    setIsLoading(false);
  }, [filterMarkersInBounds]);

  // Debounced version
  const debouncedLoadMarkers = useDebounce(
    loadMarkersForViewport,
    DEBOUNCE_DELAY
  );

  // Handle region change complete
  const handleRegionChangeComplete = useCallback(
    (event: RegionChangeEvent) => {
      if (event.isGesture) {
        debouncedLoadMarkers();
      }
    },
    [debouncedLoadMarkers]
  );

  // Handle map ready
  const handleMapReady = useCallback(() => {
    console.log('🗺️ Map ready!');
    loadMarkersForViewport();
  }, [loadMarkersForViewport]);

  // Handle cluster press
  const handleClusterPress = useCallback((event: ClusterPressEvent) => {
    mapRef.current?.animateCamera(
      {
        center: event.coordinate,
        zoom: 15,
        pitch: 0,
        heading: 0,
        altitude: 500,
      },
      400
    );
  }, []);

  // Handle marker press
  const handleMarkerPress = useCallback((event: { id: string }) => {
    setSelectedMarkerId(event.id);
    mapRef.current?.selectMarker(event.id);
  }, []);

  // Memoize rendered markers
  const renderedMarkers = useMemo(
    () =>
      markers.map((marker) => (
        <PriceMarker
          key={marker.id}
          id={marker.id}
          coordinate={{
            latitude: marker.latitude,
            longitude: marker.longitude,
          }}
          price={marker.price}
          currency="USD"
          animation="fadeIn"
          selected={selectedMarkerId === marker.id}
          // Using hex color strings directly - no need for hex() function!
          backgroundColor="#FFFFFF"
          textColor="#000"
          selectedBackgroundColor="#E53935" // Red when selected
          selectedTextColor="#FFF" // Short hex format works too
          clusteringEnabled={true}
          onPress={() => handleMarkerPress({ id: marker.id })}
        />
      )),
    [markers, selectedMarkerId, handleMarkerPress]
  );

  // Get selected marker
  const selectedMarker = useMemo(
    () => TASHKENT_MARKERS.find((m) => m.id === selectedMarkerId),
    [selectedMarkerId]
  );

  // Initial region (Tashkent Center)
  const initialRegion = {
    latitude: 41.3111,
    longitude: 69.26,
    latitudeDelta: 0.15,
    longitudeDelta: 0.15,
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerText}>🏠 Tashkent Properties</Text>
        <View style={styles.statsContainer}>
          {isLoading && <ActivityIndicator size="small" color="#4CAF50" />}
          <Text style={styles.statsText}>
            {markers.length} / {TASHKENT_MARKERS.length}
          </Text>
        </View>
      </View>

      {/* Map */}
      <NitroMap
        ref={mapRef}
        provider="google"
        darkMode={true}
        initialRegion={initialRegion}
        clusterConfig={{
          enabled: true, // Enable clustering to test
          minimumClusterSize: 5,
          maxZoom: 16,
          // Using hex color strings directly!
          backgroundColor: '#FF5733', // Orange cluster background
          textColor: '#FFFFFF', // White text
          borderWidth: 2,
          borderColor: '#FFF', // Short hex format
          animatesClusters: true,
          animationDuration: 0.25,
          animationStyle: 'fade',
        }}
        onMapReady={handleMapReady}
        onRegionChangeComplete={handleRegionChangeComplete}
        onClusterPress={handleClusterPress}
        onMarkerPress={handleMarkerPress}
      >
        {renderedMarkers}
      </NitroMap>

      {/* Footer */}
      {selectedMarker && (
        <View style={styles.footer}>
          <Text style={styles.footerText}>
            📍 {selectedMarker.id} • ${selectedMarker.price}
          </Text>
        </View>
      )}
    </View>
  );
}

// ============================================================================
// STYLES
// ============================================================================

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    backgroundColor: '#1a1a2e',
    paddingVertical: 14,
    paddingHorizontal: 16,
    paddingTop: 54,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  statsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statsText: {
    color: '#4CAF50',
    fontSize: 14,
    fontWeight: '600',
  },
  footer: {
    backgroundColor: '#1a1a2e',
    padding: 14,
  },
  footerText: {
    color: '#fff',
    fontSize: 14,
    textAlign: 'center',
  },
});
