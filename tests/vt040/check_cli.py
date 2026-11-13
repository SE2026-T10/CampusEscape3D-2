"""Chạy công cụ nhập như người dùng và xác nhận kết quả ở tệp đích."""

import argparse
import configparser
import json
import subprocess
import tempfile
from pathlib import Path


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", help="Đường dẫn Godot (dùng bản console trên Windows)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    command = [
        args.godot, "--headless", "--path", str(root), "--script",
        "res://tools/vt040/import_settings.gd", "--",
    ]

    def run(*paths):
        process = subprocess.run(
            [*command, *map(str, paths)], capture_output=True, text=True,
            encoding="utf-8", timeout=30,
        )
        result = next((line for line in process.stdout.splitlines() if line.startswith("{")), "")
        check(bool(result), f"CLI không trả JSON: {process.stdout}\n{process.stderr}")
        return process.returncode, json.loads(result)

    with tempfile.TemporaryDirectory(prefix="vt040-cli-") as folder:
        batch = Path(folder, "batch.json")
        destination = Path(folder, "settings.cfg")
        batch.write_text(json.dumps([
            {"key": "hud_scale", "value": 1.25},
            {"key": "master_volume", "value": 2},
            {"key": "captions", "value": False},
        ]), encoding="utf-8")
        destination.write_text("[settings]\nmaster_volume=0.4\n", encoding="utf-8")
        exit_code, result = run(batch, destination)
        check(exit_code == 0 and result["status"] == "partial_success" and result["saved"] == 2,
              f"T13: kết quả nhập một phần: {exit_code} {result}")
        check(result["rejected"] == [{"row": 2, "reason": "invalid_value"}], "T13: dòng lỗi")
        config = configparser.ConfigParser()
        config.read(destination, encoding="utf-8")
        check(config.getfloat("settings", "hud_scale") == 1.25
              and config.getfloat("settings", "master_volume") == 0.4
              and not config.getboolean("settings", "captions"), "T13: kết quả trên đĩa")
        exit_code, result = run(batch, Path(folder, "missing", "settings.cfg"))
        check(exit_code == 1 and result["status"] == "storage_error" and result["saved"] == 0,
              f"T14: mã thoát khi ghi lỗi: {exit_code} {result}")
        exit_code, result = run(Path(folder, "missing.json"), destination)
        check(exit_code == 1 and result["status"] == "input_error" and result["saved"] == 0,
              f"T14: mã thoát khi đọc lỗi: {exit_code} {result}")
    print("VT-040 CLI: T13/T14 passed (2 cases, 5 assertions)")


if __name__ == "__main__":
    main()
