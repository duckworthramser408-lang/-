# 捉虫子 0.6.9：绘本农场美术

根据用户提供的《美术风格.zip》八张参考图，将入口、农田、作物、虫子、行动牌和控件统一为水粉绘本风格。参考的是纸张颗粒、柔和颜料、手绘边缘和构图节奏；使用重新绘制的游戏素材。

## 颜色、构成与质感

| 用途 | 颜色 |
| --- | --- |
| 燕麦纸底 | #F5E8C9 |
| 棕色文字与轮廓 | #634936 |
| 草叶 | #8CAA70 |
| 蜂蜜强调色 | #E7B65F |
| 池水蓝 | #AFCFD2 |
| 桃色 | #D99883 |
| 月夜纸底 | #293E48 |

背景采用柔和的水粉农田，周边植物较丰富，棋盘中央保持安静。土地是独立纸片，作物带米白剪贴边和棕色轮廓。纸面控件用轻微不规则的边框、克制的阴影和原生文字。正文使用随包附带的霞鹜文楷轻便版。

## 白天与夜晚

昼夜共用 `farm_scene.png`，使用相同的 `BoxFit.cover`、居中裁切及完整屏幕尺寸，仅切换 RGB 光照。地平线、山丘、房屋、植物和地块因此完全重合。夜间叠加等尺寸透明 `night_sky.png`，只有月亮与星星，不含另外一套地形。独立绘制的夜景试稿不参与运行时渲染。

白天牌面使用米色 `action_paper.png` 和棕字；夜间使用蓝绿色 `action_night.png` 和米白字。卡号、指示顺序、动作次数、说明均由 Flutter 渲染，避免图画中文字影响规则。四向箭头继续表示整行或整列；八格图示继续表示周围八格。两者使用同一套圆润水粉笔触、稳定的不规则边缘和少量纸纹，缩略图与高清预览共用绘制代码。

用户追加提供《行动牌.zip》作为指示图形核对依据，上方图形必须保留，不能只剩文字。①②为十＋环，③环＋环，④十＋十，⑤环＋十＋十。第五张保留三个指示图形。昼夜分别导出全部五张牌的真实组件并核对每个图形的类型、数量和顺序。

## 入口与贴纸

初始规则页面及模式页面共用 `mode_scene.png`；“捉虫子”标题、25种作物贴纸与对局素材属于同一美术家族。模式页的摇动惯性、自然下落、碰撞、休眠、尺寸分布和传感器生命周期沿用 0.6.8。

## 集成与兼容

- 新素材在 `assets/storybook/`，原素材保留原始字节。
- `GameArtwork` 只改变展示副本，旧存档里的图片路径映射到对应新品种，不重写存档。空路径和自定义路径保留原接口行为。
- 作物编号、品种顺序和中心梨 ID13保持；咬痕、受损表情、标记、推理笔记、回合配色和身份隐私继续由原状态驱动。
- `FarmSceneGeometry`、棋盘点击区域、2:1分区、虫轨道、规则引擎、模型、存储、音乐、原生监听、依赖锁与应用包名保持。
- 5张行动牌仍按原 `displayInstructions` 显示；出牌必须按原操作按钮，预览和装饰不执行行动。

## 素材来源与许可

插画通过内置 `image_gen.imagegen` 生成并接入项目。完整生成与编辑提示词保存在 [ART_PROMPTS.json](ART_PROMPTS.json)，素材尺寸与 SHA-256 保存在 [STORYBOOK_ART_MANIFEST.json](STORYBOOK_ART_MANIFEST.json)。25张作物由透明图集按连通内容区域提取，纸面纹理取自牌面的空白部分。文字和规则图标是原生组件。

字体为 [LXGW WenKai Lite v1.522](https://github.com/lxgw/LxgwWenKai-Lite/releases/tag/v1.522)，按 [SIL Open Font License](https://github.com/lxgw/LxgwWenKai-Lite/blob/main/OFL.txt) 随包保留字体及 `OFL.txt`。

## 检查与实际界面导出

```bash
flutter pub get --enforce-lockfile
flutter analyze --no-pub lib test
flutter test --no-pub --reporter expanded
flutter test --no-pub --dart-define=EXPORT_ART_PREVIEWS=true test/storybook_preview_test.dart
```

最后一条使用真实中文字体导出实际 Flutter 页面到 `outputs/previews/`，包含入口、规则、白天、夜晚、牌面预览及全五张牌的昼夜图形核对图。普通测试不生成交付截图。不同屏幕的昼夜底图、裁切、装饰层与点击坐标回归见 `night_scene_test.dart`。基线逐文件核验与验证结果见 [ART_VALIDATION.json](ART_VALIDATION.json)。APK构建环境见 [DEVELOPMENT.md](DEVELOPMENT.md)。
