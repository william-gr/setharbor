"""Bound native device commands and retain their output, including on timeout."""
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def run(command, *, cwd=ROOT, timeout=900, log):
    log = Path(log)
    log.parent.mkdir(parents=True, exist_ok=True)
    print('+ ' + ' '.join(map(str, command)), flush=True)
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=cwd, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + timeout
            while process.poll() is None:
                if time.monotonic() >= deadline:
                    raise subprocess.TimeoutExpired(command, timeout)
                time.sleep(1)
            if process.returncode:
                raise subprocess.CalledProcessError(process.returncode, command)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
            print(log.read_text(errors='replace')[-16000:], flush=True)
