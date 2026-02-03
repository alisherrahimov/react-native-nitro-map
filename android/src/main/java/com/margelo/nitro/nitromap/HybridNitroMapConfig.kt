package com.margelo.nitro.nitromap

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip
import com.google.android.gms.maps.MapsInitializer
import com.yandex.mapkit.MapKitFactory

@DoNotStrip
@Keep
class HybridNitroMapConfig : HybridNitroMapConfigSpec() {

    companion object {
        private var isInitialized = false
        private var applicationContext: Context? = null
        private var googleMapsApiKey: String? = null

        fun setContext(context: Context) {
            applicationContext = context.applicationContext
        }

        fun getGoogleMapsApiKey(): String? = googleMapsApiKey
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
                // Store API key for later use and inject into app metadata
                googleMapsApiKey = apiKey
                injectGoogleMapsApiKey(context, apiKey)
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

    private fun injectGoogleMapsApiKey(context: Context, apiKey: String) {
        try {
            val appInfo: ApplicationInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA
            )
            if (appInfo.metaData == null) {
                appInfo.metaData = Bundle()
            }
            appInfo.metaData.putString("com.google.android.geo.API_KEY", apiKey)
            println("[NitroMap] Google Maps API key injected successfully")
        } catch (e: Exception) {
            println("[NitroMap] Failed to inject Google Maps API key: ${e.message}")
        }
    }

    override fun IsNitroMapInitialized(): Boolean {
        return isInitialized
    }
}
