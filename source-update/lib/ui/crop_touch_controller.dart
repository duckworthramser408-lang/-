import 'package:flutter/material.dart';
import 'farm_scene_geometry.dart';

/// 只记录正在触摸的地块，不读取身份、不参与选择、不写存档。
class CropTouchController extends ChangeNotifier {
  final Map<int, Offset> _pointers = {};
  Set<int> held = {};
  Set<int> swept = {};

  void touch(int pointer, Offset position, Size size) {
    final previous = _pointers[pointer] ?? position;
    _pointers[pointer] = position;
    held = {
      for (var id = 1; id <= 25; id++)
        if (_pointers.values.any(
          (p) => FarmSceneGeometry.plotRect(id, size).contains(p),
        ))
          id,
    };
    swept = {
      for (var id = 1; id <= 25; id++)
        if (_crosses(FarmSceneGeometry.plotRect(id, size), previous, position))
          id,
    };
    notifyListeners();
  }

  // 线段与矩形相交；快速划过时也不会漏掉两个采样点之间的作物。
  bool _crosses(Rect rect, Offset a, Offset b) {
    var low = 0.0;
    var high = 1.0;
    final delta = b - a;
    for (final axis in [
      (a.dx, delta.dx, rect.left, rect.right),
      (a.dy, delta.dy, rect.top, rect.bottom),
    ]) {
      if (axis.$2.abs() < .00001) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      } else {
        var first = (axis.$3 - axis.$1) / axis.$2;
        var last = (axis.$4 - axis.$1) / axis.$2;
        if (first > last) {
          final swap = first;
          first = last;
          last = swap;
        }
        low = low > first ? low : first;
        high = high < last ? high : last;
        if (low > high) return false;
      }
    }
    return true;
  }

  void release(int pointer, Size size) {
    _pointers.remove(pointer);
    held = {
      for (var id = 1; id <= 25; id++)
        if (_pointers.values.any(
          (p) => FarmSceneGeometry.plotRect(id, size).contains(p),
        ))
          id,
    };
    swept = {};
    notifyListeners();
  }

  void reset() {
    _pointers.clear();
    held = {};
    swept = {};
    notifyListeners();
  }
}
