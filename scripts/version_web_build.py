"""Give Flutter entry points unique URLs so browsers fetch the current release."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
revision = sys.argv[2]
if not re.fullmatch(r'[0-9a-f]{40}', revision):
    raise SystemExit('Expected a full Git commit SHA')
index = root / 'index.html'
bootstrap = root / 'flutter_bootstrap.js'
js = root / 'main.dart.js'
index_text = index.read_text()
bootstrap_text = bootstrap.read_text()
if 'flutter_bootstrap.js' not in index_text or 'main.dart.js' not in bootstrap_text or not js.is_file():
    raise SystemExit('Unexpected Flutter build layout')
bootstrap_name = f'flutter_bootstrap.{revision}.js'
js_name = f'main.{revision}.dart.js'
js.rename(root / js_name)
bootstrap.write_text(bootstrap_text.replace('main.dart.js', js_name))
bootstrap.rename(root / bootstrap_name)
index.write_text(index_text.replace('flutter_bootstrap.js', bootstrap_name))
