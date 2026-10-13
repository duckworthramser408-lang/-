package com.happiness.threads

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Preloaded one-shot sound; independent of the looping music and game state. */
class CardSoundEffects(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.happiness.threads/card_sound")
    private var pool: SoundPool? = null
    private var sample = 0
    private var popSample = 0
    private val loaded = mutableSetOf<Int>()
    private val streams = mutableListOf<Int>()
    private var foreground = true
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "prepare" -> prepare()
                    "play" -> play(sample, 0.40f)
                    "pop" -> play(popSample, 0.28f)
                    "stop" -> stop()
                    "release" -> release()
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            } catch (_: Exception) {
                release()
                result.error("sound_unavailable", "短音效暂不可用", null)
            }
        }
    }
    private fun prepare() {
        if (pool != null) return
        val next = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
        pool = next
        next.setOnLoadCompleteListener { owner, id, status ->
            if (pool === owner && status == 0) loaded.add(id)
        }
        val path = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/audio/card_chime.wav")
        context.assets.openFd(path).use { file -> sample = next.load(file, 1) }
        val popPath = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/audio/crop_pop.wav")
        context.assets.openFd(popPath).use { file -> popSample = next.load(file, 1) }
    }
    private fun play(id: Int, volume: Float) {
        if (!foreground || !loaded.contains(id)) return
        // Only two streams can sound concurrently; discard expired stream IDs.
        while (streams.size >= 2) pool?.stop(streams.removeAt(0))
        val stream = pool?.play(id, volume, volume, 1, 0, 1f) ?: 0
        if (stream != 0) streams.add(stream)
    }
    fun stop() { streams.forEach { pool?.stop(it) }; streams.clear() }
    fun setForeground(active: Boolean) { foreground = active; if (!active) stop() }
    private fun release() { stop(); loaded.clear(); sample = 0; popSample = 0; pool?.release(); pool = null }
    fun dispose() { release(); channel.setMethodCallHandler(null) }
}
