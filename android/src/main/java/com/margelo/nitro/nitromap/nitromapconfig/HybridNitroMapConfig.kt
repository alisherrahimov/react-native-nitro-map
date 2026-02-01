package com.margelo.nitro.nitromap.nitromapconfig

import android.content.Context
import com.google.android.gms.maps.MapsInitializer
import com.margelo.nitro.nitromap.HybridNitroMapConfigSpec
import com.margelo.nitro.nitromap.MapProvider
import com.yandex.mapkit.MapKitFactory

class HybridNitroMapConfig : HybridNitroMapConfigSpec() {

    companion object {
        private var isInitialized = false
        private var applicationContext: Context? = null

        fun setContext(context: Context) {
            applicationContext = context.applicationContext
        }
    }

    override fun NitroMapInitialize(apiKey: String, provider: MapProvider) {
        if (isInitialized) {
            println("[NitroMap] Already initialized")
            return
        }

        val context =
                applicationContext
                        ?: throw IllegalStateException(
                                "[NitroMap] Context not set. Call setContext() first."
                        )

        when (provider) {
            MapProvider.GOOGLE -> {
              // Inject API key into metadata before initialization
              MapsInitializer.initialize(context, MapsInitializer.Renderer.LATEST) { renderer ->
                println("[NitroMap] Google Maps initialized with renderer: $renderer")
              }
            }
            MapProvider.YANDEX -> {
              MapKitFactory.setApiKey(apiKey)
              MapKitFactory.initialize(context)
            }
            MapProvider.APPLE -> {
                // Apple Maps not available on Android
            }
        }

        isInitialized = true
    }

    override fun IsNitroMapInitialized(): Boolean {
        return isInitialized
    }
}
