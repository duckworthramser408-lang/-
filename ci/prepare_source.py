import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
archive = root / 'base/catch-bugs-0.6.8-source.zip'
expected = 'd86a332b4896f15322d5eaf80856af32b53e99bec27739b4c8484b0a70b51f67'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected, 'Baseline ZIP checksum mismatch'
app = root / 'app'
app.mkdir(exist_ok=True)
with zipfile.ZipFile(archive) as source:
    for entry in source.infolist():
        relative = Path(entry.filename.replace('\\', '/'))
        assert not relative.is_absolute() and '..' not in relative.parts, 'Unsafe archive path'
        target = app / relative
        if entry.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read(entry))
shutil.copytree(root / 'source-update', app, dirs_exist_ok=True)
font = app / 'assets/storybook/fonts/LXGWWenKaiLite-Regular.ttf'
font.parent.mkdir(parents=True, exist_ok=True)
url = 'https://github.com/lxgw/LxgwWenKai-Lite/releases/download/v1.522/LXGWWenKaiLite-Regular.ttf'
with urllib.request.urlopen(url, timeout=120) as response:
    font.write_bytes(response.read())
files = json.loads((root / 'ci/source-files.json').read_text(encoding='utf-8-sig'))
for item in files:
    target = app / item['path']
    assert target.is_file(), f"Missing source file: {item['path']}"
    assert hashlib.sha256(target.read_bytes()).hexdigest().upper() == item['sha256'], f"Source mismatch: {item['path']}"
(app / 'android/gradlew').chmod(0o755)
print(f'Prepared and verified {len(files)} source files for 0.6.11+21.')
