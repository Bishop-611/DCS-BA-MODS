"""Check distributable/source bytes, nested ZIPs and package checksums."""
import argparse
import hashlib
import io
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('--private-token', action='append', default=[])
parser.add_argument('--embedded-payload', type=Path)
args = parser.parse_args()
checked = 0
allowed_users = {'YOUR_WINDOWS_USER', 'YOUR_NAME', 'PUBLIC', 'DEFAULT', 'RUNNERADMIN'}
user_path = re.compile(r'[A-Za-z]:[\\/]+Users[\\/]+([^\\/\s\]"\'<>]+)', re.I)
developer_path = re.compile(r'[A-Za-z]:[\\/]+(?:Projects|Workspaces|Repos)[\\/]', re.I)
credential = re.compile(r'(?<![A-Za-z0-9_])(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})')

def check(data, name, depth=0):
    global checked
    checked += 1
    for encoding in ('utf-8', 'utf-16le'):
        text = data.decode(encoding, errors='ignore')
        if any(m[1].upper() not in allowed_users for m in user_path.finditer(text)):
            raise RuntimeError('Personal profile path: ' + name)
        if developer_path.search(text) or credential.search(text):
            raise RuntimeError('Private development path or credential: ' + name)
        if any(token and token.lower() in text.lower() for token in args.private_token):
            raise RuntimeError('Private identifier: ' + name)
    # Also inspect ZIP resources embedded inside .NET executables.
    stream = io.BytesIO(data)
    if depth < 4 and zipfile.is_zipfile(stream):
        with zipfile.ZipFile(stream) as archive:
            for item in archive.infolist():
                if item.is_dir():
                    continue
                if item.filename.startswith(('/', '\\')) or '..' in Path(item.filename).parts:
                    raise RuntimeError('Unsafe archive name: ' + name)
                check(archive.read(item), name + '!' + item.filename, depth + 1)

for path in sorted(args.root.rglob('*')):
    if path.is_file():
        check(path.read_bytes(), path.relative_to(args.root).as_posix())
release = args.root/'Release/0.10.13'
if args.embedded_payload:
    check(args.embedded_payload.read_bytes(), 'installer!Fox.Payload.zip')
for line in (release/'SHA256SUMS.txt').read_text().splitlines():
    digest, name = line.split(maxsplit=1)
    assert hashlib.sha256((release/name.strip()).read_bytes()).hexdigest() == digest.lower(), name
print(f'PASS: {checked} files/archive members scanned; release SHA256 checks passed.')
