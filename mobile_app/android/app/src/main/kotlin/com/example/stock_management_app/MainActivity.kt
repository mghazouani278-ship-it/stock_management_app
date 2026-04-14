package com.example.stock_management_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    /**
     * Default is [RenderMode.surface] (SurfaceView). On some devices SurfaceView never composites
     * correctly and the user only sees the window background (solid gray). Texture mode is more
     * compatible at a small performance cost.
     */
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
