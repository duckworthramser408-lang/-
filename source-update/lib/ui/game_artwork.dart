import 'dart:ui';

import '../models/girl_card.dart';
import 'crop_artwork.dart';

/// 应用的素材配置，和游戏状态/存档完全分离。
abstract final class GameArtwork {
  static const backgroundPath = 'assets/storybook/farm_scene.png';
  static const nightSkyPath = 'assets/storybook/night_sky.png';
  static const modeBackgroundPath = 'assets/storybook/mode_scene.png';
  static const plotPath = 'assets/storybook/land_plot.png';

  static String cardPath(int id) =>
      cropImagePaths[id] ??
      'assets/crops/crop${id.toString().padLeft(2, '0')}.png';

  /// 绘本素材保持原来的25种作物顺序，梨仍为ID13。
  static const cropImagePaths = <int, String>{
    1: 'assets/storybook/crops/crop01.png',
    2: 'assets/storybook/crops/crop02.png',
    3: 'assets/storybook/crops/crop03.png',
    4: 'assets/storybook/crops/crop04.png',
    5: 'assets/storybook/crops/crop05.png',
    6: 'assets/storybook/crops/crop06.png',
    7: 'assets/storybook/crops/crop07.png',
    8: 'assets/storybook/crops/crop08.png',
    9: 'assets/storybook/crops/crop09.png',
    10: 'assets/storybook/crops/crop10.png',
    11: 'assets/storybook/crops/crop11.png',
    12: 'assets/storybook/crops/crop12.png',
    13: 'assets/storybook/crops/crop13.png',
    14: 'assets/storybook/crops/crop14.png',
    15: 'assets/storybook/crops/crop15.png',
    16: 'assets/storybook/crops/crop16.png',
    17: 'assets/storybook/crops/crop17.png',
    18: 'assets/storybook/crops/crop18.png',
    19: 'assets/storybook/crops/crop19.png',
    20: 'assets/storybook/crops/crop20.png',
    21: 'assets/storybook/crops/crop21.png',
    22: 'assets/storybook/crops/crop22.png',
    23: 'assets/storybook/crops/crop23.png',
    24: 'assets/storybook/crops/crop24.png',
    25: 'assets/storybook/crops/crop25.png',
  };

  /// 原始PNG按ZIP顺序登记，梨预留在中心ID13；其他作物相对顺序不变。
  static const legacyCropImagePaths = <int, String>{
    1: 'assets/crops/包菜.png',
    2: 'assets/crops/南瓜.png',
    3: 'assets/crops/哈密瓜.png',
    4: 'assets/crops/土豆.png',
    5: 'assets/crops/大蒜.png',
    6: 'assets/crops/杨桃.png',
    7: 'assets/crops/柠檬.png',
    8: 'assets/crops/桃子.png',
    9: 'assets/crops/椰子.png',
    10: 'assets/crops/橙子.png',
    11: 'assets/crops/猕猴桃.png',
    12: 'assets/crops/玉米.png',
    13: 'assets/crops/梨.png',
    14: 'assets/crops/番茄.png',
    15: 'assets/crops/白萝卜.png',
    16: 'assets/crops/胡萝卜.png',
    17: 'assets/crops/茄子.png',
    18: 'assets/crops/草莓.png',
    19: 'assets/crops/荔枝.png',
    20: 'assets/crops/荷兰豆.png',
    21: 'assets/crops/菠萝.png',
    22: 'assets/crops/西瓜.png',
    23: 'assets/crops/青椒.png',
    24: 'assets/crops/香蕉.png',
    25: 'assets/crops/黄瓜.png',
  };

  /// 非透明边界来源于原始PNG的alpha通道，用于消除透明留白。
  static const cropArtwork = <String, CropArtwork>{
    'assets/storybook/crops/crop01.png': CropArtwork(
      path: 'assets/storybook/crops/crop01.png',
      sourceSize: Size(254, 209),
      contentBounds: Rect.fromLTWH(3, 3, 248, 203),
    ),
    'assets/storybook/crops/crop02.png': CropArtwork(
      path: 'assets/storybook/crops/crop02.png',
      sourceSize: Size(220, 206),
      contentBounds: Rect.fromLTWH(3, 3, 214, 200),
    ),
    'assets/storybook/crops/crop03.png': CropArtwork(
      path: 'assets/storybook/crops/crop03.png',
      sourceSize: Size(203, 230),
      contentBounds: Rect.fromLTWH(3, 3, 197, 224),
    ),
    'assets/storybook/crops/crop04.png': CropArtwork(
      path: 'assets/storybook/crops/crop04.png',
      sourceSize: Size(190, 216),
      contentBounds: Rect.fromLTWH(3, 3, 184, 210),
    ),
    'assets/storybook/crops/crop05.png': CropArtwork(
      path: 'assets/storybook/crops/crop05.png',
      sourceSize: Size(229, 205),
      contentBounds: Rect.fromLTWH(3, 3, 223, 199),
    ),
    'assets/storybook/crops/crop06.png': CropArtwork(
      path: 'assets/storybook/crops/crop06.png',
      sourceSize: Size(181, 198),
      contentBounds: Rect.fromLTWH(3, 3, 175, 192),
    ),
    'assets/storybook/crops/crop07.png': CropArtwork(
      path: 'assets/storybook/crops/crop07.png',
      sourceSize: Size(223, 218),
      contentBounds: Rect.fromLTWH(3, 3, 217, 212),
    ),
    'assets/storybook/crops/crop08.png': CropArtwork(
      path: 'assets/storybook/crops/crop08.png',
      sourceSize: Size(213, 217),
      contentBounds: Rect.fromLTWH(3, 3, 207, 211),
    ),
    'assets/storybook/crops/crop09.png': CropArtwork(
      path: 'assets/storybook/crops/crop09.png',
      sourceSize: Size(234, 206),
      contentBounds: Rect.fromLTWH(3, 3, 228, 200),
    ),
    'assets/storybook/crops/crop10.png': CropArtwork(
      path: 'assets/storybook/crops/crop10.png',
      sourceSize: Size(210, 231),
      contentBounds: Rect.fromLTWH(3, 3, 204, 225),
    ),
    'assets/storybook/crops/crop11.png': CropArtwork(
      path: 'assets/storybook/crops/crop11.png',
      sourceSize: Size(248, 195),
      contentBounds: Rect.fromLTWH(3, 3, 242, 189),
    ),
    'assets/storybook/crops/crop12.png': CropArtwork(
      path: 'assets/storybook/crops/crop12.png',
      sourceSize: Size(179, 239),
      contentBounds: Rect.fromLTWH(3, 3, 173, 233),
    ),
    'assets/storybook/crops/crop13.png': CropArtwork(
      path: 'assets/storybook/crops/crop13.png',
      sourceSize: Size(190, 242),
      contentBounds: Rect.fromLTWH(3, 3, 184, 236),
    ),
    'assets/storybook/crops/crop14.png': CropArtwork(
      path: 'assets/storybook/crops/crop14.png',
      sourceSize: Size(208, 199),
      contentBounds: Rect.fromLTWH(3, 3, 202, 193),
    ),
    'assets/storybook/crops/crop15.png': CropArtwork(
      path: 'assets/storybook/crops/crop15.png',
      sourceSize: Size(166, 267),
      contentBounds: Rect.fromLTWH(3, 3, 160, 261),
    ),
    'assets/storybook/crops/crop16.png': CropArtwork(
      path: 'assets/storybook/crops/crop16.png',
      sourceSize: Size(168, 248),
      contentBounds: Rect.fromLTWH(3, 3, 162, 242),
    ),
    'assets/storybook/crops/crop17.png': CropArtwork(
      path: 'assets/storybook/crops/crop17.png',
      sourceSize: Size(210, 233),
      contentBounds: Rect.fromLTWH(3, 3, 204, 227),
    ),
    'assets/storybook/crops/crop18.png': CropArtwork(
      path: 'assets/storybook/crops/crop18.png',
      sourceSize: Size(205, 225),
      contentBounds: Rect.fromLTWH(3, 3, 199, 219),
    ),
    'assets/storybook/crops/crop19.png': CropArtwork(
      path: 'assets/storybook/crops/crop19.png',
      sourceSize: Size(226, 182),
      contentBounds: Rect.fromLTWH(3, 3, 220, 176),
    ),
    'assets/storybook/crops/crop20.png': CropArtwork(
      path: 'assets/storybook/crops/crop20.png',
      sourceSize: Size(212, 233),
      contentBounds: Rect.fromLTWH(3, 3, 206, 227),
    ),
    'assets/storybook/crops/crop21.png': CropArtwork(
      path: 'assets/storybook/crops/crop21.png',
      sourceSize: Size(166, 237),
      contentBounds: Rect.fromLTWH(3, 3, 160, 231),
    ),
    'assets/storybook/crops/crop22.png': CropArtwork(
      path: 'assets/storybook/crops/crop22.png',
      sourceSize: Size(227, 201),
      contentBounds: Rect.fromLTWH(3, 3, 221, 195),
    ),
    'assets/storybook/crops/crop23.png': CropArtwork(
      path: 'assets/storybook/crops/crop23.png',
      sourceSize: Size(208, 220),
      contentBounds: Rect.fromLTWH(3, 3, 202, 214),
    ),
    'assets/storybook/crops/crop24.png': CropArtwork(
      path: 'assets/storybook/crops/crop24.png',
      sourceSize: Size(211, 223),
      contentBounds: Rect.fromLTWH(3, 3, 205, 217),
    ),
    'assets/storybook/crops/crop25.png': CropArtwork(
      path: 'assets/storybook/crops/crop25.png',
      sourceSize: Size(143, 226),
      contentBounds: Rect.fromLTWH(3, 3, 137, 220),
    ),
    'assets/crops/包菜.png': CropArtwork(
      path: 'assets/crops/包菜.png',
      sourceSize: Size(1312, 1199),
      contentBounds: Rect.fromLTWH(25, 50, 1273, 1134),
    ),
    'assets/crops/南瓜.png': CropArtwork(
      path: 'assets/crops/南瓜.png',
      sourceSize: Size(1374, 1145),
      contentBounds: Rect.fromLTWH(37, 33, 1309, 1058),
    ),
    'assets/crops/哈密瓜.png': CropArtwork(
      path: 'assets/crops/哈密瓜.png',
      sourceSize: Size(1304, 1206),
      contentBounds: Rect.fromLTWH(194, 63, 1096, 1109),
    ),
    'assets/crops/土豆.png': CropArtwork(
      path: 'assets/crops/土豆.png',
      sourceSize: Size(1254, 1254),
      contentBounds: Rect.fromLTWH(41, 109, 1197, 1103),
    ),
    'assets/crops/大蒜.png': CropArtwork(
      path: 'assets/crops/大蒜.png',
      sourceSize: Size(1312, 1199),
      contentBounds: Rect.fromLTWH(92, 41, 1150, 1140),
    ),
    'assets/crops/杨桃.png': CropArtwork(
      path: 'assets/crops/杨桃.png',
      sourceSize: Size(1374, 1145),
      contentBounds: Rect.fromLTWH(55, 49, 1281, 1030),
    ),
    'assets/crops/柠檬.png': CropArtwork(
      path: 'assets/crops/柠檬.png',
      sourceSize: Size(1299, 1211),
      contentBounds: Rect.fromLTWH(41, 37, 1180, 1152),
    ),
    'assets/crops/桃子.png': CropArtwork(
      path: 'assets/crops/桃子.png',
      sourceSize: Size(1312, 1199),
      contentBounds: Rect.fromLTWH(63, 0, 1149, 1159),
    ),
    'assets/crops/椰子.png': CropArtwork(
      path: 'assets/crops/椰子.png',
      sourceSize: Size(1374, 1145),
      contentBounds: Rect.fromLTWH(72, 37, 1229, 1052),
    ),
    'assets/crops/橙子.png': CropArtwork(
      path: 'assets/crops/橙子.png',
      sourceSize: Size(1254, 1254),
      contentBounds: Rect.fromLTWH(154, 121, 939, 1027),
    ),
    'assets/crops/猕猴桃.png': CropArtwork(
      path: 'assets/crops/猕猴桃.png',
      sourceSize: Size(1536, 1024),
      contentBounds: Rect.fromLTWH(41, 36, 1271, 924),
    ),
    'assets/crops/玉米.png': CropArtwork(
      path: 'assets/crops/玉米.png',
      sourceSize: Size(1145, 1374),
      contentBounds: Rect.fromLTWH(0, 0, 1032, 1374),
    ),
    'assets/crops/梨.png': CropArtwork(
      path: 'assets/crops/梨.png',
      sourceSize: Size(1297, 1212),
      contentBounds: Rect.fromLTWH(191, 49, 866, 1163),
    ),
    'assets/crops/番茄.png': CropArtwork(
      path: 'assets/crops/番茄.png',
      sourceSize: Size(1292, 1217),
      contentBounds: Rect.fromLTWH(0, 54, 1282, 1087),
    ),
    'assets/crops/白萝卜.png': CropArtwork(
      path: 'assets/crops/白萝卜.png',
      sourceSize: Size(1024, 1536),
      contentBounds: Rect.fromLTWH(63, 47, 891, 1465),
    ),
    'assets/crops/胡萝卜.png': CropArtwork(
      path: 'assets/crops/胡萝卜.png',
      sourceSize: Size(1024, 1536),
      contentBounds: Rect.fromLTWH(31, 84, 953, 1416),
    ),
    'assets/crops/茄子.png': CropArtwork(
      path: 'assets/crops/茄子.png',
      sourceSize: Size(1262, 1246),
      contentBounds: Rect.fromLTWH(122, 0, 1088, 1212),
    ),
    'assets/crops/草莓.png': CropArtwork(
      path: 'assets/crops/草莓.png',
      sourceSize: Size(1254, 1254),
      contentBounds: Rect.fromLTWH(124, 103, 969, 1079),
    ),
    'assets/crops/荔枝.png': CropArtwork(
      path: 'assets/crops/荔枝.png',
      sourceSize: Size(1536, 1024),
      contentBounds: Rect.fromLTWH(115, 39, 1385, 921),
    ),
    'assets/crops/荷兰豆.png': CropArtwork(
      path: 'assets/crops/荷兰豆.png',
      sourceSize: Size(1226, 1283),
      contentBounds: Rect.fromLTWH(0, 77, 1075, 1152),
    ),
    'assets/crops/菠萝.png': CropArtwork(
      path: 'assets/crops/菠萝.png',
      sourceSize: Size(1142, 1377),
      contentBounds: Rect.fromLTWH(162, 5, 829, 1372),
    ),
    'assets/crops/西瓜.png': CropArtwork(
      path: 'assets/crops/西瓜.png',
      sourceSize: Size(1254, 1254),
      contentBounds: Rect.fromLTWH(41, 39, 1179, 1215),
    ),
    'assets/crops/青椒.png': CropArtwork(
      path: 'assets/crops/青椒.png',
      sourceSize: Size(1298, 1212),
      contentBounds: Rect.fromLTWH(129, 2, 1147, 1194),
    ),
    'assets/crops/香蕉.png': CropArtwork(
      path: 'assets/crops/香蕉.png',
      sourceSize: Size(1312, 1199),
      contentBounds: Rect.fromLTWH(0, 58, 1280, 1123),
    ),
    'assets/crops/黄瓜.png': CropArtwork(
      path: 'assets/crops/黄瓜.png',
      sourceSize: Size(1024, 1536),
      contentBounds: Rect.fromLTWH(127, 5, 879, 1484),
    ),
  };

  static CropArtwork? cropForPath(String path) => cropArtwork[path];

  /// 展示副本不写回旧存档。旧人物/旧作物路径只在展示时映射到新绘本素材。
  /// 显式空路径继续关闭图片；新的自定义作物路径优先。
  static GirlCard cardForDisplay(GirlCard girl) {
    final path = girl.cardImagePath;
    if (path != null &&
        (path.trim().startsWith('assets/cards/') ||
            legacyCropImagePaths.values.contains(path.trim()))) {
      return girl.copyWith(cardImagePath: cropImagePaths[girl.id]);
    }
    return path == null
        ? girl.copyWith(cardImagePath: cropImagePaths[girl.id])
        : girl;
  }
}
