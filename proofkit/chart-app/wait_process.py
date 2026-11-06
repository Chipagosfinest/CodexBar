"""Bounded observed process exit; avoids platform event-notification wait paths."""
import subprocess
import time


def observed_exit(process, timeout):
    deadline = time.monotonic() + timeout
    while True:
        result = process.poll()
        if result is not None:
            return result
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(process.args, timeout)
        time.sleep(min(0.1, remaining))
