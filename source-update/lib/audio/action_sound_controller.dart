import 'package:flutter/services.dart';

/// 页面级短音效，不写入存档或音乐偏好；非安卓环境可静默运行。
class ActionSoundController {
  static const channel = MethodChannel('com.happiness.threads/card_sound');
  bool _disposed = false;
  Future<void> _invoke(String method) async {
    try { await channel.invokeMethod<void>(method); }
    on PlatformException { /* 音效不可用不影响出牌。 */ }
    on MissingPluginException { /* 预览与测试无原生音频。 */ }
  }
  Future<void> prepare() => _disposed ? Future.value() : _invoke('prepare');
  Future<void> play() => _disposed ? Future.value() : _invoke('play');
  Future<void> pop() => _disposed ? Future.value() : _invoke('pop');
  Future<void> stop() => _invoke('stop');
  void dispose() { _disposed = true; _invoke('release'); }
}
