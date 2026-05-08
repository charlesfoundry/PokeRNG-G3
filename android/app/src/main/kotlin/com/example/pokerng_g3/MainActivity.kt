package com.example.pokerng_g3

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var timerBeepPlayer: TimerBeepPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        timerBeepPlayer = TimerBeepPlayer(this, flutterEngine).also { it.configure() }
    }

    override fun onDestroy() {
        timerBeepPlayer?.release()
        timerBeepPlayer = null
        super.onDestroy()
    }
}

private class TimerBeepPlayer(
    private val context: Context,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "pokerng_g3/timer_beep",
    )
    private val soundPool: SoundPool
    private var soundId = 0
    private var loaded = false
    private var loading = false
    private val pendingPrepareResults = mutableListOf<MethodChannel.Result>()

    init {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setMaxStreams(1)
            .setAudioAttributes(attributes)
            .build()
        soundPool.setOnLoadCompleteListener { _, loadedSoundId, status ->
            if (loadedSoundId != soundId) {
                return@setOnLoadCompleteListener
            }
            loaded = status == 0
            loading = false
            val results = pendingPrepareResults.toList()
            pendingPrepareResults.clear()
            for (result in results) {
                if (loaded) {
                    result.success(null)
                } else {
                    result.error("load_failed", "Timer beep failed to load.", null)
                }
            }
        }
    }

    fun configure() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> prepare(result)
                "play" -> play(result)
                else -> result.notImplemented()
            }
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
        soundPool.release()
        pendingPrepareResults.clear()
    }

    private fun prepare(result: MethodChannel.Result) {
        if (loaded) {
            result.success(null)
            return
        }
        pendingPrepareResults.add(result)
        if (loading) {
            return
        }
        loading = true
        try {
            val assetKey = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset("assets/audio/timer_beep.wav")
            context.assets.openFd(assetKey).use { descriptor ->
                soundId = soundPool.load(descriptor, 1)
            }
        } catch (error: Exception) {
            loading = false
            val results = pendingPrepareResults.toList()
            pendingPrepareResults.clear()
            for (pendingResult in results) {
                pendingResult.error("load_failed", error.message, null)
            }
        }
    }

    private fun play(result: MethodChannel.Result) {
        if (!loaded) {
            result.error("not_ready", "Timer beep is not loaded.", null)
            return
        }
        soundPool.play(soundId, 0.6f, 0.6f, 1, 0, 1f)
        result.success(null)
    }
}
