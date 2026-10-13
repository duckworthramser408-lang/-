import 'dart:math' as math;
import 'dart:ui';

/// 模式页贴纸的独立物理状态；不引用游戏模型，也不写入存档。
class ModeStickerBody {
  ModeStickerBody({
    required this.position,
    required this.diameter,
    this.angle = 0,
  });
  Offset position;
  Offset velocity = Offset.zero;
  final double diameter;
  double angle;
  double angularVelocity = 0;

  // 碰撞圆覆盖作物主体，透明图片留白允许自然交叠；屏幕边界则保护整图。
  double get radius => diameter * .36;
  double get wallInset => diameter * .64;
  double get inverseMass => 1 / (radius * radius);
}

/// 贴纸沿手机重力方向飘落，柔性接触允许相互滑过，不使用摇动发射或随机弹跳。
/// 固定120Hz子步保证不同手机帧率下相同的运动；落稳后停止帧循环。
class ModeStickerPhysics {
  ModeStickerPhysics({
    required this.size,
    required double edge,
    required List<double> scales,
  }) : bodies = [
         for (var i = 0; i < scales.length; i++)
           ModeStickerBody(
             diameter: edge * scales[i],
             position: Offset(
               size.width * (.10 + (i % 5) * .20),
               size.height * (.10 + (i ~/ 5) * .18),
             ),
             angle: (i % 5 - 2) * .10,
           ),
       ] {
    for (final body in bodies) {
      _walls(body);
    }
  }

  final Size size;
  final List<ModeStickerBody> bodies;
  bool get isSleeping => _sleeping;
  bool _sleeping = true;
  double _accumulator = 0;
  double _quietTime = 0;
  Offset _gravityDirection = Offset.zero;
  Rect get bounds => Rect.fromLTRB(
    -size.width * .20,
    -size.height * .20,
    size.width * 1.20,
    size.height * 1.20,
  );
  double get gravity => size.height * .75;

  // 保留旧公开入口；含义改为更新重力方向，绝不直接改速度。
  void shake(Offset acceleration) {
    setGravity(acceleration);
  }

  void setGravity(Offset acceleration) {
    if (!acceleration.dx.isFinite || !acceleration.dy.isFinite) {
      return;
    }
    var direction = acceleration / 9.81;
    if (direction.distance > 1) direction /= direction.distance;
    if (direction.distance < .025) direction = Offset.zero;
    if ((direction - _gravityDirection).distance < .025) return;
    _gravityDirection = direction;
    _sleeping = false;
    _quietTime = 0;
  }

  /// 返回是否还需要下一帧。输入停止后仍继续惯性、落下和接触处理。
  bool advance(double elapsedSeconds) {
    if (_sleeping || !elapsedSeconds.isFinite || elapsedSeconds <= 0) {
      return !_sleeping;
    }
    _accumulator += elapsedSeconds.clamp(0, .05);
    const step = 1 / 120;
    while (_accumulator >= step && !_sleeping) {
      _accumulator -= step;
      _step(step);
    }
    return !_sleeping;
  }

  void _step(double dt) {
    final before = [for (final body in bodies) body.position];
    for (final body in bodies) {
      body.velocity =
          (body.velocity + _gravityDirection * gravity * dt) *
          math.exp(-dt * .75);
      final limit = size.shortestSide * .60;
      if (body.velocity.distance > limit) {
        body.velocity *= limit / body.velocity.distance;
      }
      body.position += body.velocity * dt;
      body.angle = (body.angle + body.angularVelocity * dt).clamp(-.32, .32);
      body.angularVelocity *= math.exp(-dt * 1.5);
    }
    // 多轮解接触，避免底层贴纸在上层重量下穿透地板或互相卡入。
    for (var pass = 0; pass < 6; pass++) {
      for (var i = 0; i < bodies.length; i++) {
        for (var j = i + 1; j < bodies.length; j++) {
          _collide(bodies[i], bodies[j], i, j);
        }
      }
      for (final body in bodies) {
        _walls(body);
      }
    }
    // 接触堆叠的速度解有微小残差：先确认每张贴纸由边界或
    // 下方贴纸支撑，再按实际位移判断落稳，不能在空中提前休眠。
    final supported = _supportedBodies();
    var quiet = true;
    for (var i = 0; i < bodies.length; i++) {
      if (!supported[i] ||
          (bodies[i].position - before[i]).distance > size.height * .0002 ||
          (_gravityDirection == Offset.zero &&
              bodies[i].velocity.distance > 2)) {
        quiet = false;
        break;
      }
    }
    _quietTime = quiet ? _quietTime + dt : 0;
    if (_quietTime > .8) {
      _sleeping = true;
      _accumulator = 0;
      for (final body in bodies) {
        body.velocity = Offset.zero;
        body.angularVelocity = 0;
      }
    }
  }

  List<bool> _supportedBodies() {
    if (_gravityDirection == Offset.zero) {
      return List.filled(bodies.length, true);
    }
    final direction = _gravityDirection / _gravityDirection.distance;
    final supported = [
      for (final body in bodies)
        (direction.dx < -.05 &&
                body.position.dx <= bounds.left + body.wallInset + .5) ||
            (direction.dx > .05 &&
                body.position.dx >= bounds.right - body.wallInset - .5) ||
            (direction.dy < -.05 &&
                body.position.dy <= bounds.top + body.wallInset + .5) ||
            (direction.dy > .05 &&
                body.position.dy >= bounds.bottom - body.wallInset - .5),
    ];
    for (var pass = 0; pass < bodies.length; pass++) {
      var changed = false;
      for (var i = 0; i < bodies.length; i++) {
        if (supported[i]) continue;
        for (var j = 0; j < bodies.length; j++) {
          if (!supported[j] || i == j) continue;
          final delta = bodies[j].position - bodies[i].position;
          final distance = delta.distance;
          if (distance <= bodies[i].radius + bodies[j].radius + 1 &&
              delta.dx * direction.dx + delta.dy * direction.dy >
                  distance * .20) {
            supported[i] = true;
            changed = true;
            break;
          }
        }
      }
      if (!changed) break;
    }
    return supported;
  }

  void _collide(ModeStickerBody a, ModeStickerBody b, int i, int j) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    final overlap = a.radius + b.radius - distance;
    if (overlap <= 0) return;
    var normal = distance > .0001
        ? delta / distance
        : Offset(i < j ? 1 : -1, 0);
    // 纸片之间不承重：仅沿重力的切线分散，不形成刚体高塔。
    if (_gravityDirection != Offset.zero) {
      final down = _gravityDirection / _gravityDirection.distance;
      final tangent = Offset(-down.dy, down.dx);
      final side = normal.dx * tangent.dx + normal.dy * tangent.dy;
      normal = tangent * (side.abs() > .01 ? side.sign : (i < j ? 1 : -1));
    }
    final mass = a.inverseMass + b.inverseMass;
    a.position -= normal * overlap * .12 * a.inverseMass / mass;
    b.position += normal * overlap * .12 * b.inverseMass / mass;
    final relative = b.velocity - a.velocity;
    final normalSpeed = relative.dx * normal.dx + relative.dy * normal.dy;
    if (normalSpeed < 0) {
      final impulse = normal * (-normalSpeed * 1.0 / mass);
      a.velocity -= impulse * a.inverseMass;
      b.velocity += impulse * b.inverseMass;
      final tangent = relative - normal * normalSpeed;
      final friction = tangent * .025 / mass;
      a.velocity += friction * a.inverseMass;
      b.velocity -= friction * b.inverseMass;
      a.angularVelocity *= .93;
      b.angularVelocity *= .93;
    }
  }

  void _walls(ModeStickerBody body) {
    final inset = body.wallInset;
    final left = math.min(bounds.left + inset, size.width / 2);
    final top = math.min(bounds.top + inset, size.height / 2);
    final right = math.max(left, bounds.right - inset);
    final bottom = math.max(top, bounds.bottom - inset);
    var vx = body.velocity.dx;
    var vy = body.velocity.dy;
    if (body.position.dx < left && vx < 0 ||
        body.position.dx > right && vx > 0) {
      vx *= -.04;
    }
    if (body.position.dy < top && vy < 0) vy *= -.04;
    if (body.position.dy >= bottom && vy > 0) {
      vy = 0;
      vx *= .98;
      body.angularVelocity *= .8;
    }
    body.position = Offset(
      body.position.dx.clamp(left, right),
      body.position.dy.clamp(top, bottom),
    );
    body.velocity = Offset(vx, vy);
  }
}
