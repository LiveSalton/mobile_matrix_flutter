#!/usr/bin/env python3
"""Restricted Airtest runner for the local Mobile Matrix control plane."""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4


PROJECT_ROOT = Path(__file__).resolve().parents[5]
TASK_ROOT = PROJECT_ROOT / "scripts" / "airtest"
TASKS = {
    "capture": {
        "title": "Capture current screen",
        "description": "Capture a fresh screen without changing device content.",
        "script": None,
    },
    "douyin_follow_message": {
        "title": "Douyin follow + greeting",
        "description": "Run the existing Douyin profile verification and greeting task.",
        "script": TASK_ROOT / "douyin_follow_message.air" / "douyin_follow_message.py",
    },
}


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))


def engine_status():
    import airtest  # pylint: disable=import-outside-toplevel

    emit({"available": True, "version": getattr(airtest, "__version__", "unknown")})


def evidence_root():
    return Path(os.environ.get(
        "AIRTEST_EVIDENCE_DIR",
        PROJECT_ROOT / ".runtime" / "airtest-evidence",
    ))


def take_snapshot(device, evidence_dir: Path, name: str):
    evidence_dir.mkdir(parents=True, exist_ok=True)
    target = evidence_dir / name
    device.snapshot(filename=str(target))
    return target.name


def execute_capture(serial, evidence_dir: Path):
    from airtest.core.api import connect_device  # pylint: disable=import-outside-toplevel

    started = time.monotonic()
    device = connect_device(
        "Android:///{}?cap_method=ADBCAP&touch_method=ADBTOUCH".format(serial)
    )

    screenshot = take_snapshot(device, evidence_dir, "capture.png")
    emit({
        "status": "succeeded",
        "serial": device.uuid,
        "task": "capture",
        "resolution": device.get_current_resolution(),
        "durationMs": int((time.monotonic() - started) * 1000),
        "screenshots": [screenshot],
    })


def execute_script(serial, task_id, evidence_dir: Path):
    descriptor = TASKS[task_id]
    script = descriptor["script"]
    if not script or not script.is_file():
        raise ValueError("Task script is missing: {}".format(task_id))

    completed = subprocess.run(
        [
            sys.executable,
            str(script),
            "--device",
            serial,
            "--evidence-dir",
            str(evidence_dir),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    lines = completed.stdout.strip().splitlines()
    result = None
    for line in reversed(lines):
        try:
            result = json.loads(line)
            break
        except json.JSONDecodeError:
            continue
    if result is None:
        result = {
            "status": "failed",
            "reason": "Airtest task did not return a structured result",
        }
    result["task"] = task_id
    result["serial"] = result.get("serial", serial)
    result["screenshots"] = sorted(
        item.name for item in evidence_dir.glob("*.png")
    )
    if completed.returncode != 0 and result.get("status") == "completed":
        result["status"] = "failed"
    emit(result)


def execute(serial, task_id, evidence_dir: Path):
    if task_id not in TASKS:
        raise ValueError("Unsupported task: {}".format(task_id))
    if task_id == "capture":
        execute_capture(serial, evidence_dir)
    else:
        execute_script(serial, task_id, evidence_dir)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--serial")
    parser.add_argument("--task", choices=sorted(TASKS))
    parser.add_argument("--action", choices=["capture"], help=argparse.SUPPRESS)
    parser.add_argument("--evidence-dir", type=Path)
    args = parser.parse_args()

    try:
        if args.status:
            engine_status()
            return
        task_id = args.task or args.action
        if not args.serial or not task_id:
            raise ValueError("serial and task are required")
        evidence_dir = args.evidence_dir or evidence_root() / uuid4().hex
        execute(args.serial, task_id, evidence_dir)
    except Exception as err:  # Airtest exposes device-specific exception types.
        emit({"status": "failed", "message": str(err)})
        sys.exit(1)


if __name__ == "__main__":
    main()
