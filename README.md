# 捉虫子 0.6.9 · 绘本美术版

本分支保存 0.6.8 原始源码 ZIP 与 0.6.9 美术更新文件，并使用 GitHub Actions 构建安卓安装包。

- 完整游戏源码：运行 `python3 ci/prepare_source.py` 后位于 `app/`，256 个源码文件逐项核验 SHA-256。
- 原始源码 ZIP：`base/catch-bugs-0.6.8-source.zip`，与用户提供的原包 SHA-256 一致。
- 新素材及修改：`source-update/`；原规则、模型、存档、原生配置与 40 份原素材保持。
- 构建配置：`.github/workflows/build-apk.yml`；Flutter 3.47.6、JDK 17。
- 构建通过后自动发布 [0.6.9 APK、完整源码与校验记录](https://github.com/duckworthramser408-lang/catch-bug-app/releases/tag/v0.6.9)。

昼夜共用农田底图和裁切，地平线一致；卡牌、箭头、入口和贴纸统一水粉绘本风格。五张行动牌的图形顺序保持：十＋环、十＋环、环＋环、十＋十、环＋十＋十。

旧版签名密钥未包含在源码中，能否覆盖安装以发布附件 `APK-validation.json` 的 `same_upgrade_signature` 为准。未进行真机测试。
文楷字体从官方 v1.522 版本下载，并按清单验证 SHA-256；字体和许可证均包含在最终源码 ZIP 与 APK 中。
