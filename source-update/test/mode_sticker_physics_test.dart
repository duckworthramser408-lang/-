import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/ui/mode_sticker_physics.dart';
import 'package:happiness_threads/ui/widgets/mode_sticker_scene.dart';

void main() {
  test('30和60帧手机使用相同子步，倾斜飘落轨迹不依赖刷新率', () {
    ModeStickerPhysics scene() => ModeStickerPhysics(
      size: const Size(360, 640),
      edge: 50,
      scales: ModeStickerScene.stickerScales,
    )..setGravity(const Offset(4, 8));
    final slow = scene();
    final fast = scene();
    for (var i = 0; i < 60; i++) {
      fast.advance(1 / 60);
      if (i.isEven) slow.advance(1 / 30);
    }
    for (var i = 0; i < 25; i++) {
      expect(
        (slow.bodies[i].position - fast.bodies[i].position).distance,
        lessThan(.01),
      );
    }
  });

  for (final direction in [
    const Offset(9.81, 0),
    const Offset(-9.81, 0),
    const Offset(0, 9.81),
    const Offset(0, -9.81),
  ]) {
    test('手机重力$direction轻柔飘落，无即时发射或随机弹起', () {
      final scene = ModeStickerPhysics(
        size: const Size(360, 640),
        edge: 50,
        scales: const [1],
      );
      final body = scene.bodies.single;
      body.position = const Offset(180, 320);
      scene.setGravity(direction);
      expect(body.velocity, Offset.zero);
      final initial = body.position;
      scene.advance(1 / 60);
      expect((body.position - initial).distance, lessThan(.15));
      for (var i = 0; i < 120; i++) {
        scene.advance(1 / 60);
        expect(body.velocity.distance, lessThanOrEqualTo(216.001));
      }
      final displacement = body.position - initial;
      expect(
        displacement.dx * direction.dx + displacement.dy * direction.dy,
        greaterThan(100),
      );
      expect(
        (displacement.dx * direction.dy - displacement.dy * direction.dx).abs(),
        lessThan(.01),
      );
      final beforeChange = body.velocity;
      scene.setGravity(-direction);
      expect(body.velocity, beforeChange);
      for (var i = 0; i < 120; i++) {
        scene.advance(1 / 60);
      }
      expect(
        body.velocity.dx * direction.dx + body.velocity.dy * direction.dy,
        lessThan(0),
      );
    });
  }

  for (final size in [const Size(360, 640), const Size(800, 1280)]) {
    test('${size.width}加快飘落、不承重堆塔、扩展边界、稳定重力下休眠，倾斜改变再唤醒', () {
      final physics = ModeStickerPhysics(
        size: size,
        edge: size.width * .14,
        scales: ModeStickerScene.stickerScales,
      )..setGravity(const Offset(0, 9.81));
      for (var frame = 0; frame < 7200 && !physics.isSleeping; frame++) {
        physics.advance(1 / 60);
        for (final body in physics.bodies) {
          expect(
            body.position.dx - body.wallInset,
            greaterThanOrEqualTo(-size.width * .20 - .001),
          );
          expect(
            body.position.dx + body.wallInset,
            lessThanOrEqualTo(size.width * 1.20 + .001),
          );
          expect(
            body.position.dy - body.wallInset,
            greaterThanOrEqualTo(-size.height * .20 - .001),
          );
          expect(
            body.position.dy + body.wallInset,
            lessThanOrEqualTo(size.height * 1.20 + .001),
          );
        }
      }
      expect(physics.isSleeping, isTrue, reason: '稳定重力下落稳停止刷新');
      final onFloor = physics.bodies
          .where(
            (b) =>
                (b.position.dy - (size.height * 1.20 - b.wallInset)).abs() < 1,
          )
          .length;
      expect(onFloor, greaterThanOrEqualTo(20));
      final settled = physics.bodies.map((b) => b.position).toList();
      physics.setGravity(const Offset(0, 9.81));
      expect(physics.isSleeping, isTrue);
      expect(physics.advance(10), isFalse);
      expect(physics.bodies.map((b) => b.position), settled);
      physics.setGravity(const Offset(-9, 3));
      expect(physics.isSleeping, isFalse);
      for (var frame = 0; frame < 120; frame++) {
        physics.advance(1 / 60);
      }
      expect(physics.bodies.map((b) => b.position), isNot(settled));
    });
  }

  test('平放、异常输入不唤醒，尺寸仅为对局同作物一到两倍', () {
    final quiet = ModeStickerPhysics(
      size: const Size(360, 640),
      edge: 50,
      scales: ModeStickerScene.stickerScales,
    );
    quiet.setGravity(Offset.zero);
    quiet.setGravity(const Offset(double.nan, 3));
    expect(quiet.isSleeping, isTrue);
    expect(quiet.advance(double.infinity), isFalse);
    expect(ModeStickerScene.stickerScales.reduce((a, b) => a > b ? a : b), 2);
    expect(ModeStickerScene.stickerScales.reduce((a, b) => a < b ? a : b), 1);
    expect(ModeStickerScene.stickerScales.toSet().length, 25);
  });
}
