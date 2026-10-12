import 'package:flutter/material.dart';

/// 原作物透明内容视口内的损伤坐标；不移动或修改原图。
abstract final class CropDamageArtwork {
  static Offset faceCenter(String path) =>
      _storybookFaceCenters[path] ??
      _faceCenters[path] ??
      const Offset(.49, .63);

  static Offset biteCenter(String path) => switch (path) {
    'assets/crops/白萝卜.png' ||
    'assets/storybook/crops/crop15.png' => const Offset(.75, .65),
    'assets/crops/胡萝卜.png' ||
    'assets/storybook/crops/crop16.png' => const Offset(.74, .65),
    'assets/crops/荔枝.png' ||
    'assets/storybook/crops/crop19.png' => const Offset(.76, .67),
    'assets/crops/荷兰豆.png' ||
    'assets/storybook/crops/crop20.png' => const Offset(.91, .81),
    _ => const Offset(.93, .50),
  };

  static double faceWidth(String path) => switch (path) {
    'assets/crops/猕猴桃.png' ||
    'assets/crops/荔枝.png' ||
    'assets/storybook/crops/crop11.png' ||
    'assets/storybook/crops/crop19.png' => .38,
    'assets/crops/荷兰豆.png' || 'assets/storybook/crops/crop20.png' => .40,
    _ => .57,
  };

  static const _storybookFaceCenters = <String, Offset>{
    'assets/storybook/crops/crop01.png': Offset(.50, .56),
    'assets/storybook/crops/crop02.png': Offset(.50, .55),
    'assets/storybook/crops/crop03.png': Offset(.46, .61),
    'assets/storybook/crops/crop04.png': Offset(.50, .55),
    'assets/storybook/crops/crop05.png': Offset(.50, .65),
    'assets/storybook/crops/crop06.png': Offset(.48, .56),
    'assets/storybook/crops/crop07.png': Offset(.50, .62),
    'assets/storybook/crops/crop08.png': Offset(.50, .66),
    'assets/storybook/crops/crop09.png': Offset(.38, .52),
    'assets/storybook/crops/crop10.png': Offset(.50, .62),
    'assets/storybook/crops/crop11.png': Offset(.28, .49),
    'assets/storybook/crops/crop12.png': Offset(.50, .49),
    'assets/storybook/crops/crop13.png': Offset(.51, .68),
    'assets/storybook/crops/crop14.png': Offset(.50, .68),
    'assets/storybook/crops/crop15.png': Offset(.50, .63),
    'assets/storybook/crops/crop16.png': Offset(.50, .61),
    'assets/storybook/crops/crop17.png': Offset(.65, .49),
    'assets/storybook/crops/crop18.png': Offset(.50, .65),
    'assets/storybook/crops/crop19.png': Offset(.32, .64),
    'assets/storybook/crops/crop20.png': Offset(.55, .57),
    'assets/storybook/crops/crop21.png': Offset(.50, .70),
    'assets/storybook/crops/crop22.png': Offset(.49, .57),
    'assets/storybook/crops/crop23.png': Offset(.50, .62),
    'assets/storybook/crops/crop24.png': Offset(.42, .63),
    'assets/storybook/crops/crop25.png': Offset(.55, .53),
  };

  // 分品种覆盖原笑脸，多果拼图和细长作物分别适配。
  static const _faceCenters = <String, Offset>{
    'assets/crops/包菜.png': Offset(.49, .52),
    'assets/crops/南瓜.png': Offset(.50, .59),
    'assets/crops/哈密瓜.png': Offset(.43, .59),
    'assets/crops/土豆.png': Offset(.49, .47),
    'assets/crops/大蒜.png': Offset(.50, .63),
    'assets/crops/杨桃.png': Offset(.55, .48),
    'assets/crops/柠檬.png': Offset(.49, .58),
    'assets/crops/桃子.png': Offset(.51, .61),
    'assets/crops/椰子.png': Offset(.43, .57),
    'assets/crops/橙子.png': Offset(.51, .60),
    'assets/crops/猕猴桃.png': Offset(.43, .43),
    'assets/crops/玉米.png': Offset(.58, .46),
    'assets/crops/梨.png': Offset(.53, .63),
    'assets/crops/番茄.png': Offset(.51, .64),
    'assets/crops/白萝卜.png': Offset(.50, .57),
    'assets/crops/胡萝卜.png': Offset(.51, .50),
    'assets/crops/茄子.png': Offset(.61, .51),
    'assets/crops/草莓.png': Offset(.52, .58),
    'assets/crops/荔枝.png': Offset(.32, .57),
    'assets/crops/荷兰豆.png': Offset(.47, .51),
    'assets/crops/菠萝.png': Offset(.48, .67),
    'assets/crops/西瓜.png': Offset(.50, .53),
    'assets/crops/青椒.png': Offset(.45, .59),
    'assets/crops/香蕉.png': Offset(.44, .62),
    'assets/crops/黄瓜.png': Offset(.62, .43),
  };
}
