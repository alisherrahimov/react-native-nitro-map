package com.margelo.nitro.nitromap

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

import com.margelo.nitro.nitromap.views.HybridNitroMapManager

class NitroMapPackage : BaseReactPackage() {
    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        // Set context for HybridNitroMapConfig on first module access
        HybridNitroMapConfig.setContext(reactContext)
        return null
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider { HashMap() }
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        // Set context for HybridNitroMapConfig
        HybridNitroMapConfig.setContext(reactContext)
        return listOf(HybridNitroMapManager())
    }

    companion object {
        init {
            System.loadLibrary("nitromap")
        }
    }
}
