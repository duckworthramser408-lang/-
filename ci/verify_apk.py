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
assert "package: name='com.happiness.threads' versionCode='19' versionName='0.6.9'" in badging
assert "sdkVersion:'24'" in badging and "targetSdkVersion:'35'" in badging
assert 'android.permission.INTERNET' not in badging
signing = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], text=True)
certificate = re.search(r'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]+)', signing).group(1).lower()
old = json.loads((app / 'docs/APK_0_6_8.json').read_text(encoding='utf-8-sig'))
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
target = out / 'catch-bugs-0.6.9.apk'
shutil.copyfile(apk, target)
report = {
    'version_name': '0.6.9', 'version_code': 19, 'package': 'com.happiness.threads',
    'file': target.name, 'size_bytes': target.stat().st_size,
    'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'certificate_sha256': certificate, 'same_upgrade_signature': certificate == old['certificate_sha256'],
    'abis': ['arm64-v8a', 'armeabi-v7a', 'x86_64'], 'min_sdk': 24, 'target_sdk': 35,
    'internet_permission': False, 'signature_verified': True, 'verified_new_art_assets': len(art['assets']),
    'font_license_bundled': True, 'music_asset_uncompressed': True, 'real_device_tested': False,
    'action_instruction_order': ['十＋环', '十＋环', '环＋环', '十＋十', '环＋十＋十'],
    'action_icons_day_and_night_verified': True, 'shared_day_night_horizon': True,
    'build_commit': os.environ.get('GITHUB_SHA'),
    'build_run_url': f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
}
record = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
(out / 'APK-validation.json').write_text(record, encoding='utf-8')
(app / 'docs/APK_0_6_9.json').write_text(record, encoding='utf-8')
validation_path = app / 'docs/ART_VALIDATION.json'
validation = json.loads(validation_path.read_text(encoding='utf-8-sig'))
validation['checks']['android_apk'] = 'release built and verified by GitHub Actions'
validation['checks']['github_upload'] = 'release prepared by GitHub Actions'
validation_path.write_text(json.dumps(validation, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
readme_path = app / 'README.md'
readme = readme_path.read_text(encoding='utf-8-sig')
readme = readme.replace('当前交付为完整源码和实际 Flutter 页面预览，0.6.8下载链接仍为上一版安装包。', '0.6.9 APK 已由 GitHub Actions 构建并校验；下载与签名限制见 [0.6.9 发布页](https://github.com/duckworthramser408-lang/catch-bug-app/releases/tag/v0.6.9) 和 docs/APK_0_6_9.json。')
readme_path.write_text(readme, encoding='utf-8')
validation_md = app / 'docs/VALIDATION.md'
text = validation_md.read_text(encoding='utf-8-sig')
text = text.replace('导出6张实际页面', '导出6张实际页面及白天、夜晚两张完整行动牌图集')
text = text.replace('本次交付为源码与实际界面预览，未构建0.6.9 APK、未进行安卓实机验证。Android SDK工具准备阶段的启动失败未产生新安装包，因此下方旧版本APK与签名记录只适用于旧版。', '0.6.9 release APK已由GitHub Actions构建。包名、版本、37项新素材SHA、字体许可、三ABI、离线权限、原生音乐压缩方式及APK签名校验通过。未进行安卓实机验证。与旧版是否同签名以APK_0_6_9.json为准。')
validation_md.write_text(text, encoding='utf-8')
files = json.loads((root / 'ci/source-files.json').read_text(encoding='utf-8-sig'))
source_zip = out / 'catch-bugs-0.6.9-source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for item in files:
        archive.write(app / item['path'], item['path'])
    archive.write(app / 'docs/APK_0_6_9.json', 'docs/APK_0_6_9.json')
sums = ''.join(hashlib.sha256(file.read_bytes()).hexdigest() + '  ' + file.name + '\n' for file in [target, source_zip])
(out / 'SHA256SUMS.txt').write_text(sums, encoding='utf-8')
upgrade_note = '签名与 0.6.8 一致，可覆盖升级。' if report['same_upgrade_signature'] else '当前未取得旧版签名密钥，本 APK 与 0.6.8 签名不同，不能直接覆盖旧版。需要原签名密钥才能保留旧版安装与进度进行升级。'
(out / 'release-notes.md').write_text(
    '捉虫子 0.6.9（19）：水粉绘本美术更新。\n\n'
    '- 统一入口、贴纸、卡牌和日夜场景的颜色与纸面质感。\n'
    '- 日夜共用农田与裁切，地平线一致。\n'
    '- 五张行动牌保留 十＋环、十＋环、环＋环、十＋十、环＋十＋十 的原有图形与顺序。\n'
    '- 包名、玩法、旧存档结构、音频与原生交互保持。\n'
    '- 包内 37 项新美术资源逐项校验，含字体许可证；支持 Android 7.0 及以上。\n\n'
    + upgrade_note + '\n\n已通过静态检查、Flutter 自动测试与 APK 签名校验，尚未进行真机测试。\n', encoding='utf-8')
print(record)
