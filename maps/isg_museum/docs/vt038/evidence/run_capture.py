from datetime import datetime
import json
from pathlib import Path
import subprocess
import sys


def main():
    name, timeout, *command = sys.argv[1:]
    evidence = Path(__file__).resolve().parent
    info = {
        'command': command,
        'working_directory': str(Path.cwd()),
        'start': datetime.now().astimezone().isoformat(),
        'timeout_seconds': int(timeout),
    }
    with (evidence / f'{name}.stdout.log').open('wb') as out, (evidence / f'{name}.stderr.log').open('wb') as err:
        try:
            info['exit_code'] = subprocess.run(command, stdout=out, stderr=err, timeout=int(timeout)).returncode
        except subprocess.TimeoutExpired:
            info['exit_code'] = None
            info['timed_out'] = True
    info['end'] = datetime.now().astimezone().isoformat()
    (evidence / f'{name}.json').write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')
    print(f'{name}: exit {info["exit_code"]}')
    return 124 if info['exit_code'] is None else info['exit_code']


if __name__ == '__main__':
    sys.exit(main())
