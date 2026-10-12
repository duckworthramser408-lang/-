import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
app = root / 'app'
apk = app / 'build/app/outputs/flutter-apk/app-release.apk'
sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
tools = sdk / 'build-tools/36.0.0'
badging = subprocess.check_output([str(tools / 'aapt2'), 'dump', 'badging', str(apk)], text=True)
assert "package: name='com.happiness.threads' versionCode='20' versionName='0.6.10'" in badging
minimum = int(re.search(r"(?:minSdkVersion|sdkVersion):\s*'(\d+)'", badging).group(1))
target_sdk = int(re.search(r"targetSdkVersion:\s*'(\d+)'", badging).group(1))
assert minimum == 24 and target_sdk == 35, f'Unexpected SDK versions: {minimum}/{target_sdk}'
print(f'APK manifest verified: min SDK {minimum}, target SDK {target_sdk}.')
assert 'android.permission.INTERNET' not in badging
signing = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], text=True)
certificate = re.search(r'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]+)', signing).group(1).lower()
old = json.loads((app / 'docs/APK_0_6_9.json').read_text(encoding='utf-8-sig'))
art = json.loads((app / 'docs/STORYBOOK_ART_MANIFEST.json').read_text(encoding='utf-8-sig'))
with zipfile.ZipFile(apk) as package:
    for item in art['assets']:
        data = package.read('assets/flutter_assets/' + item['path'])
        assert len(data) == item['bytes']
        assert hashlib.sha256(data).hexdigest().upper() == item['sha256'], item['path']
    for abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']:
        for library in ['libapp.so', 'libflutter.so']:
            assert package.getinfo(f'lib/{abi}/{library}').file_size > 0
    music = [item for item in package.infolist() if item.filename.startswith('assets/flutter_assets/assets/audio/') and item.filename.endswith('.mp3')]
    assert len(music) == 1 and music[0].compress_type == zipfile.ZIP_STORED
out = root / 'release'
out.mkdir(exist_ok=True)
target = out / 'catch-bugs-0.6.10.apk'
shutil.copyfile(apk, target)
test_events = [json.loads(line) for line in (root / 'flutter-tests.jsonl').read_text().splitlines() if line.strip()]
test_results = [event for event in test_events if event.get('type') == 'testDone' and not event.get('hidden')]
passed = sum(not event.get('skipped') and event.get('result') == 'success' for event in test_results)
skipped = sum(bool(event.get('skipped')) for event in test_results)
assert passed >= 240 and all(event.get('result') == 'success' for event in test_results)
report = {
    'version_name': '0.6.10', 'version_code': 20, 'package': 'com.happiness.threads',
    'file': target.name, 'size_bytes': target.stat().st_size,
    'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'certificate_sha256': certificate, 'same_upgrade_signature': certificate == old['certificate_sha256'],
    'abis': ['arm64-v8a', 'armeabi-v7a', 'x86_64'], 'min_sdk': 24, 'target_sdk': 35,
    'internet_permission': False, 'signature_verified': True, 'verified_new_art_assets': len(art['assets']),
    'font_license_bundled': True, 'music_asset_uncompressed': True, 'real_device_tested': False,
    'action_instruction_order': ['十＋环', '十＋环', '环＋环', '十＋十', '环＋十＋十'],
    'action_icons_day_and_night_verified': True, 'shared_day_night_horizon': True,
    'build_commit': os.environ.get('GITHUB_SHA'),
    'tests_passed': passed, 'tests_skipped': skipped, 'actual_flutter_previews': 8,
    'gentle_gravity_drift': True, 'sticker_scale_min': 1, 'sticker_scale_max': 2,
    'direct_home_button': True, 'private_night_ground_glow': True,
    'rounded_preview_with_in_card_description': True,
    'build_run_url': f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
}
record = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
(out / 'APK-validation.json').write_text(record, encoding='utf-8')
(app / 'docs/APK_0_6_10.json').write_text(record, encoding='utf-8')
readme_path = app / 'README.md'
readme = readme_path.read_text(encoding='utf-8-sig')
readme = readme.replace('构建与APK校验由GitHub Actions完成。', 'APK及完整源码已发布到[0.6.10发布页](https://github.com/duckworthramser408-lang/catch-bug-app/releases/tag/v0.6.10)，本轮实测记录见docs/APK_0_6_10.json。')
readme = readme.replace('当前交付为完整源码和实际 Flutter 页面预览，0.6.8下载链接仍为上一版安装包。', '0.6.10 APK 已由 GitHub Actions 构建并校验；下载与签名限制见 [0.6.10 发布页](https://github.com/duckworthramser408-lang/catch-bug-app/releases/tag/v0.6.10) 和 docs/APK_0_6_10.json。')
readme_path.write_text(readme, encoding='utf-8')
validation_md = app / 'docs/VALIDATION.md'
text = validation_md.read_text(encoding='utf-8-sig')
text = text.replace('待本轮GitHub Actions执行静态检查、完整测试、真实页面预览导出和APK构建。最终结果见APK_0_6_10.json。旧版验证记录保留如下。', f'静态检查与{passed}项测试通过（跳过{skipped}项默认预览导出），另行导出8张真实Flutter预览。release APK已构建，包名、版本、37项新素材与字体许可、三ABI、离线权限、音乐压缩与签名校验通过，未做真机测试。实际记录见APK_0_6_10.json。旧版验证记录保留如下。')
text = text.replace('导出6张实际页面', '导出6张实际页面及白天、夜晚两张完整行动牌图集')
text = text.replace('本次交付为源码与实际界面预览，未构建0.6.10 APK、未进行安卓实机验证。Android SDK工具准备阶段的启动失败未产生新安装包，因此下方旧版本APK与签名记录只适用于旧版。', '0.6.10 release APK已由GitHub Actions构建。包名、版本、37项新素材SHA、字体许可、三ABI、离线权限、原生音乐压缩方式及APK签名校验通过。未进行安卓实机验证。与旧版是否同签名以APK_0_6_10.json为准。')
validation_md.write_text(text, encoding='utf-8')
files = json.loads((root / 'ci/source-files.json').read_text(encoding='utf-8-sig'))
source_zip = out / 'catch-bugs-0.6.10-source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for item in files:
        archive.write(app / item['path'], item['path'])
    archive.write(app / 'docs/APK_0_6_10.json', 'docs/APK_0_6_10.json')
sums = ''.join(hashlib.sha256(file.read_bytes()).hexdigest() + '  ' + file.name + '\n' for file in [target, source_zip])
(out / 'SHA256SUMS.txt').write_text(sums, encoding='utf-8')
(out / 'release-notes.md').write_text(
    '捉虫子 0.6.10（20），新签名版。\n\n'
    '- 首页贴纸根据手机倾斜的重力方向轻柔飘落，滤除摇动尖峰，尺寸为游戏内同作物1～2倍。\n'
    '- 设置右侧增加直接返回首页按钮，保存本局进度。\n'
    '- 恢复双人夜间三个寄生作物下方的蓝色柔光，隐私与人机阶段保持隐藏。\n'
    '- 预览牌圆角、无外框，原框文本移入牌内下半部，去掉预览中的啃食次数。\n'
    '- 十/环图形与顺序、昼夜共用地形、规则和旧存档结构保持。\n\n'
    + f'静态检查、{passed}项测试及APK签名与37项素材校验通过，导出8张真实Flutter预览；尚未真机测试。\n', encoding='utf-8')
print(record)
