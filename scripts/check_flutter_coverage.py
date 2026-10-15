"""Fail closed: every Dart logic/platform file needs 90% lines and 80% branches."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1] / 'flutter_app'

def verify(report):
    records = {}
    current = None
    for line in Path(report).read_text().splitlines():
        if line.startswith('SF:'):
            raw = Path(line[3:])
            current = str(raw.relative_to(ROOT)) if raw.is_absolute() else raw.as_posix()
            records[current] = {'lines': [], 'branches': []}
        elif current and line.startswith('DA:'):
            records[current]['lines'].append(int(line.split(',')[1]) > 0)
        elif current and line.startswith('BRDA:'):
            value = line.rsplit(',', 1)[1]
            records[current]['branches'].append(value != '-' and int(value) > 0)
    failures = []
    files = [p for p in (ROOT / 'lib').rglob('*.dart') if p != ROOT / 'lib/main.dart' and 'ui' not in p.relative_to(ROOT / 'lib').parts]
    if not files:
        raise ValueError('No logic files found')
    for file in sorted(files):
        name = file.relative_to(ROOT).as_posix()
        data = records.get(name)
        if not data or not data['lines']:
            failures.append(f'{name}: missing coverage')
            continue
        for kind, minimum in [('lines', .90), ('branches', .80)]:
            values = data[kind]
            # Branch-free files are valid; branch instrumentation is required globally.
            ratio = sum(values) / len(values) if values else 1
            print(f'{name}: {kind} {sum(values)}/{len(values)} ({ratio:.1%})')
            if ratio < minimum:
                failures.append(f'{name}: {kind} {ratio:.1%} < {minimum:.0%}')
    if not any(record['branches'] for record in records.values()):
        failures.append('Branch coverage data missing; use flutter test --branch-coverage')
    if failures:
        raise ValueError('\n'.join(failures))

if __name__ == '__main__':
    try:
        verify(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'coverage/lcov.info')
    except (ValueError, OSError) as error:
        sys.exit(str(error))
