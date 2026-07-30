#!/usr/bin/env python3

import os
import signal
import subprocess
import sys


def _terminate_process_group(process: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=10)
        return
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    process.wait()


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Usage: run_with_timeout.py <seconds> <command> [argument ...]",
            file=sys.stderr,
        )
        return 64
    try:
        timeout_seconds = int(sys.argv[1])
    except ValueError:
        print("Timeout must be a positive integer.", file=sys.stderr)
        return 64
    if timeout_seconds <= 0:
        print("Timeout must be a positive integer.", file=sys.stderr)
        return 64

    process = subprocess.Popen(sys.argv[2:], start_new_session=True)

    def forward_signal(signum: int, _frame: object) -> None:
        _terminate_process_group(process)
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGINT, forward_signal)
    signal.signal(signal.SIGTERM, forward_signal)

    try:
        return_code = process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        print(
            f"Command exceeded the {timeout_seconds}-second limit: "
            f"{sys.argv[2]}",
            file=sys.stderr,
            flush=True,
        )
        _terminate_process_group(process)
        return 124
    if return_code < 0:
        return 128 + abs(return_code)
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
