import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 模式页独立的装饰性运动输入；不读取、修改或保存游戏状态。
/// Android原生加速度计无需权限/联网；无传感器时保持静态贴纸。
class ModeMotionController extends ChangeNotifier {
  static const controlChannel = MethodChannel(
    'com.happiness.threads/mode_motion_control',
  );
  static const eventChannel = EventChannel('com.happiness.threads/mode_motion');
  // 仅限制异常传感器输入，不限制贴纸在屏幕内的运动距离。
  static const maximumAcceleration = 30.0;
  StreamSubscription<dynamic>? _subscription;
  Offset? _gravity;
  Offset _target = Offset.zero;
  int _generation = 0;
  bool _disposed = false;

  Offset get target => _target;

  Future<void> start() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    _gravity = null;
    _setTarget(Offset.zero);
    try {
      final available = await controlChannel.invokeMethod<bool>('isAvailable');
      if (_disposed || generation != _generation || available != true) return;
      _subscription = eventChannel.receiveBroadcastStream().listen(
        acceptAccelerometerSample,
        onError: (_) => _setTarget(Offset.zero),
      );
    } on MissingPluginException {
      // 桌面、测试环境或不支持的设备：静态展示，模式按钮照常可用。
    } on PlatformException {
      _setTarget(Offset.zero);
    }
  }

  /// 低通提取手机重力的屏幕投影；持续倾斜保留飘落方向。
  /// 不把高通摇动变成发射冲量，异常尖峰忽略，噪声不重复唤醒。
  void acceptAccelerometerSample(dynamic sample) {
    if (_disposed || sample is! List || sample.length < 2) return;
    final x = sample[0];
    final y = sample[1];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return;
    final acceleration = Offset(x.toDouble(), y.toDouble());
    if (acceleration.distance > maximumAcceleration) return;
    // 屏幕投影最多一个重力单位，摇动再快也不会增加飘落速度。
    final bounded = acceleration.distance > 9.81
        ? acceleration * (9.81 / acceleration.distance)
        : acceleration;
    _gravity = _gravity == null
        ? bounded
        : _gravity! * .92 + bounded * .08;
    // 竖屏坐标：物理x向左、屏幕x向右；物理y向上、屏幕y向下。
    final mapped = Offset(-_gravity!.dx, _gravity!.dy);
    _setTarget(mapped.distance < .20 ? Offset.zero : mapped);
  }

  void _setTarget(Offset value) {
    if (_disposed ||
        value == _target ||
        (value != Offset.zero && (value - _target).distance < .12)) {
      return;
    }
    _target = value;
    notifyListeners();
  }

  Future<void> stop() async {
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    _gravity = null;
    _setTarget(Offset.zero);
    await subscription?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
