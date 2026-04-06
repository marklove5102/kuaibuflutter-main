package com.example.kuaibuflutter

import android.content.Intent
import android.speech.tts.TextToSpeech
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kuaibu/tts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTtsEngines" -> {
                    val engines = getTtsEngines()
                    result.success(engines)
                }
                "openTtsSettings" -> {
                    openTtsSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getTtsEngines(): List<Map<String, String>> {
        try {
            val tts = TextToSpeech(applicationContext, null)
            val engines = tts.engines
            tts.shutdown()
            
            android.util.Log.d("MainActivity", "获取到 ${engines.size} 个TTS引擎")
            engines.forEach { engine ->
                android.util.Log.d("MainActivity", "引擎: ${engine.name} - ${engine.label}")
            }
            
            return engines.map { engine ->
                mapOf(
                    "name" to engine.name,
                    "label" to engine.label.toString(),
                    "isSystem" to "true"
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "获取TTS引擎失败", e)
            e.printStackTrace()
            return emptyList()
        }
    }

    private fun openTtsSettings() {
        try {
            val intent = Intent()
            intent.action = "com.android.settings.TTS_SETTINGS"
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }
}
