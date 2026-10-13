package com.happiness.threads

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 允许系统截图；秘密身份仍由Flutter的隐私提示与前后台遮挡保护。
class MainActivity : FlutterActivity() {
    private var modeMotion: ModeMotionStream? = null
    private var cardSound: CardSoundEffects? = null
    private var player: MediaPlayer? = null
    private var prepared = false
    private var desiredPlaying = false
    private var foreground = true
    private var focusGranted = false
    private var focusRequest: AudioFocusRequest? = null
    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                focusGranted = true
                player?.setVolume(0.35f, 0.35f)
                startIfReady()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> player?.setVolume(0.10f, 0.10f)
            else -> {
                focusGranted = false
                cardSound?.stop()
                pauseIfPlaying()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        modeMotion?.dispose()
        modeMotion = ModeMotionStream(this, flutterEngine.dartExecutor.binaryMessenger)
        cardSound?.dispose()
        cardSound = CardSoundEffects(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.happiness.threads/background_music").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "setPlaying" -> {
                        desiredPlaying = call.argument<Boolean>("playing") == true
                        if (desiredPlaying && foreground) {
                            requestFocus()
                            preparePlayer()
                            startIfReady()
                        } else {
                            pauseIfPlaying()
                            abandonFocus()
                        }
                        result.success(null)
                    }
                    "release" -> {
                        releasePlayer()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                releasePlayer()
                result.error("audio_unavailable", "无法播放本地背景音乐", null)
            }
        }
    }

    private fun preparePlayer() {
        if (player != null) return
        val next = MediaPlayer()
        player = next
        next.setAudioAttributes(attributes)
        next.isLooping = true
        next.setVolume(0.35f, 0.35f)
        next.setOnPreparedListener { ready ->
            if (player === ready) {
                prepared = true
                startIfReady()
            }
        }
        next.setOnErrorListener { failed, _, _ ->
            if (player === failed) releasePlayer()
            true
        }
        val asset = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(
            "assets/audio/background_music.mp3")
        assets.openFd(asset).use { file ->
            next.setDataSource(file.fileDescriptor, file.startOffset, file.length)
        }
        next.prepareAsync()
    }

    private fun startIfReady() {
        if (prepared && desiredPlaying && foreground && focusGranted) player?.start()
    }

    // 准备完成但尚未获得焦点时，MediaPlayer仍是Prepared状态，不能pause。
    private fun pauseIfPlaying() {
        val current = player ?: return
        if (prepared && current.isPlaying) current.pause()
    }

    @Suppress("DEPRECATION")
    private fun requestFocus() {
        if (focusGranted) return
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build().also { focusRequest = it }
            audioManager.requestAudioFocus(request)
        } else {
            audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN)
        }
        focusGranted = granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            audioManager.abandonAudioFocus(focusListener)
        }
        focusGranted = false
    }

    private fun releasePlayer() {
        desiredPlaying = false
        prepared = false
        player?.release()
        player = null
        abandonFocus()
    }

    override fun onStart() {
        super.onStart()
        foreground = true
    }

    override fun onResume() {
        super.onResume()
        cardSound?.setForeground(true)
        modeMotion?.onResume()
    }

    override fun onPause() {
        cardSound?.setForeground(false)
        modeMotion?.onPause()
        super.onPause()
    }

    override fun onStop() {
        foreground = false
        pauseIfPlaying()
        abandonFocus()
        super.onStop()
    }

    override fun onDestroy() {
        cardSound?.dispose()
        cardSound = null
        modeMotion?.dispose()
        modeMotion = null
        releasePlayer()
        super.onDestroy()
    }
}
