#!/usr/bin/env python3
"""Search a Douyin account, follow it when needed, then send one greeting."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from airtest.core.api import (
    Template,
    connect_device,
    exists,
    find_all,
    snapshot,
    sleep,
    start_app,
    stop_app,
    text,
    touch,
)


PACKAGE_NAME = "com.ss.android.ugc.aweme"
DEFAULT_DOUYIN_ID = "91553231518"
DEFAULT_MESSAGE = "你好"
BASE_RESOLUTION = (1280, 2800)
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_EVIDENCE_DIR = SCRIPT_DIR.parents[2] / "tmp" / "airtest" / "run"


class FlowError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="通过 Airtest 搜索抖音号、按需关注并发送一次私信。",
    )
    parser.add_argument("--douyin-id", default=DEFAULT_DOUYIN_ID)
    parser.add_argument("--message", default=DEFAULT_MESSAGE)
    parser.add_argument("--device", help="ADB 设备序列号；留空时要求只连接一台设备。")
    parser.add_argument(
        "--send",
        action="store_true",
        help="允许真实发送私信；未指定时只验证到私信页。",
    )
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=DEFAULT_EVIDENCE_DIR,
    )
    return parser.parse_args()


def connect(serial: str | None):
    device_path = serial or ""
    uri = f"Android:///{device_path}?cap_method=ADBCAP&touch_method=ADBTOUCH"
    return connect_device(uri)


def tap_ratio(device, x_ratio: float, y_ratio: float) -> None:
    width, height = device.get_current_resolution()
    touch((round(width * x_ratio), round(height * y_ratio)))


def save_evidence(evidence_dir: Path, name: str) -> Path:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    target = evidence_dir / f"{name}.png"
    snapshot(filename=str(target))
    return target


def template(name: str, *, threshold: float, record_pos: tuple[float, float]):
    target = SCRIPT_DIR / name
    if not target.is_file():
        raise FlowError(f"缺少 Airtest 模板：{target}")
    return Template(
        str(target),
        threshold=threshold,
        record_pos=record_pos,
        resolution=BASE_RESOLUTION,
    )


def require_template(target: Template, message: str):
    position = exists(target)
    if not position:
        raise FlowError(message)
    return position


def red_ratio(screen: np.ndarray, box: tuple[float, float, float, float]) -> float:
    height, width = screen.shape[:2]
    left, top, right, bottom = box
    region = screen[
        round(height * top) : round(height * bottom),
        round(width * left) : round(width * right),
    ]
    if region.size == 0:
        raise FlowError("关注按钮检测区域为空")

    blue = region[:, :, 0].astype(np.int16)
    green = region[:, :, 1].astype(np.int16)
    red = region[:, :, 2].astype(np.int16)
    red_pixels = (red > 175) & (red > green + 35) & (red > blue + 35)
    return float(red_pixels.mean())


def ensure_followed(device, evidence_dir: Path) -> str:
    action_box = (0.04, 0.40, 0.49, 0.47)
    before = device.snapshot()
    before_ratio = red_ratio(before, action_box)
    if before_ratio < 0.12:
        return "already_followed"

    tap_ratio(device, 0.265, 0.435)
    sleep(3)
    save_evidence(evidence_dir, "06_after_follow")
    after_ratio = red_ratio(device.snapshot(), action_box)
    if after_ratio >= 0.12:
        raise FlowError(
            f"点击关注后按钮仍呈红色：before={before_ratio:.3f}, "
            f"after={after_ratio:.3f}"
        )
    return "followed_now"


def restore_input_method(device, original_ime: str | None) -> None:
    if not original_ime or "netease.nie.yosemite" in original_ime:
        return
    device.shell(f"ime set {original_ime}")


def run(args: argparse.Namespace) -> dict[str, str]:
    profile_template = template(
        f"profile_id_{args.douyin_id}.png",
        threshold=0.68,
        record_pos=(0.05, -0.29),
    )
    private_message_template = template(
        "private_message.png",
        threshold=0.82,
        record_pos=(0.21, -0.07),
    )
    reply_required_template = template(
        "reply_required.png",
        threshold=0.80,
        record_pos=(-0.11, 0.46),
    )
    send_button_template = template(
        "send_button.png",
        threshold=0.82,
        record_pos=(0.40, 0.13),
    )
    send_failed_template = template(
        "send_failed.png",
        threshold=0.82,
        record_pos=(0.18, 0.02),
    )

    device = connect(args.device)
    original_ime = device.shell("settings get secure default_input_method").strip()
    result = {
        "douyin_id": args.douyin_id,
        "follow_status": "not_checked",
        "message_status": "not_checked",
    }

    try:
        stop_app(PACKAGE_NAME)
        start_app(PACKAGE_NAME)
        sleep(3)
        save_evidence(args.evidence_dir, "01_home")

        tap_ratio(device, 0.925, 0.065)
        sleep(1.5)
        save_evidence(args.evidence_dir, "02_search")

        tap_ratio(device, 0.42, 0.06)
        text(args.douyin_id, search=True, enter=False)
        sleep(3)
        save_evidence(args.evidence_dir, "03_search_results")

        tap_ratio(device, 0.265, 0.137)
        sleep(2)
        save_evidence(args.evidence_dir, "04_user_results")

        tap_ratio(device, 0.36, 0.235)
        sleep(3)
        save_evidence(args.evidence_dir, "05_profile")
        require_template(profile_template, "主页抖音号与目标不匹配，已停止操作")

        result["follow_status"] = ensure_followed(device, args.evidence_dir)
        private_position = require_template(
            private_message_template,
            "关注后未找到“发私信”按钮",
        )
        touch(private_position)
        sleep(2.5)
        save_evidence(args.evidence_dir, "07_message_page")

        restriction_visible = bool(exists(reply_required_template))

        if not args.send:
            result["message_status"] = (
                "restricted_not_sent" if restriction_visible else "ready_not_sent"
            )
            return result

        failures_before = len(find_all(send_failed_template) or [])
        tap_ratio(device, 0.40, 0.965)
        text(args.message, enter=False)
        sleep(1)
        send_position = require_template(
            send_button_template,
            "输入消息后未找到发送按钮",
        )
        touch(send_position)
        sleep(4)
        save_evidence(args.evidence_dir, "08_after_send")

        failures_after = len(find_all(send_failed_template) or [])
        if failures_after > failures_before:
            result["message_status"] = "send_failed"
            return result
        result["message_status"] = "sent"
        return result
    finally:
        restore_input_method(device, original_ime)


def main() -> int:
    args = parse_args()
    try:
        result = run(args)
    except Exception as error:
        try:
            save_evidence(args.evidence_dir, "99_failure")
        except Exception:
            pass
        print(
            json.dumps(
                {"status": "failed", "reason": str(error)},
                ensure_ascii=False,
            )
        )
        return 1

    print(json.dumps({"status": "completed", **result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
