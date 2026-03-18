#!/usr/bin/env python3

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, List


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def resolve_reference_path(value: str) -> Path:
    candidate = Path(value)
    if candidate.is_dir():
        return candidate / "opening_reference.json"
    return candidate


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def compare_json(expected: Any, actual: Any, path: str, diffs: List[str]) -> None:
    if type(expected) is not type(actual):
        diffs.append(f"{path}: type mismatch expected {type(expected).__name__}, got {type(actual).__name__}")
        return

    if isinstance(expected, dict):
        expected_keys = set(expected.keys())
        actual_keys = set(actual.keys())
        for missing_key in sorted(expected_keys - actual_keys):
            diffs.append(f"{path}: missing key '{missing_key}'")
        for extra_key in sorted(actual_keys - expected_keys):
            diffs.append(f"{path}: unexpected key '{extra_key}'")
        for key in sorted(expected_keys & actual_keys):
            compare_json(expected[key], actual[key], f"{path}.{key}", diffs)
        return

    if isinstance(expected, list):
        if len(expected) != len(actual):
            diffs.append(f"{path}: length mismatch expected {len(expected)}, got {len(actual)}")
            return
        for index, (expected_item, actual_item) in enumerate(zip(expected, actual)):
            compare_json(expected_item, actual_item, f"{path}[{index}]", diffs)
        return

    if expected != actual:
        diffs.append(f"{path}: expected {expected!r}, got {actual!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two HeartGold opening reference roots or opening_reference.json files.")
    parser.add_argument("--expected", required=True, help="Expected opening root or opening_reference.json path")
    parser.add_argument("--actual", required=True, help="Actual opening root or opening_reference.json path")
    args = parser.parse_args()

    expected_reference_path = resolve_reference_path(args.expected)
    actual_reference_path = resolve_reference_path(args.actual)
    expected_root = expected_reference_path.parent
    actual_root = actual_reference_path.parent

    expected_reference = load_json(expected_reference_path)
    actual_reference = load_json(actual_reference_path)

    diffs: List[str] = []
    compare_json(expected_reference, actual_reference, "opening_reference", diffs)

    expected_traces = {
        (trace["sceneID"], trace["cueName"]): trace
        for trace in expected_reference.get("audioTraces", [])
    }
    actual_traces = {
        (trace["sceneID"], trace["cueName"]): trace
        for trace in actual_reference.get("audioTraces", [])
    }

    for trace_key in sorted(expected_traces.keys() & actual_traces.keys()):
        expected_trace_path = expected_root / expected_traces[trace_key]["traceRelativePath"]
        actual_trace_path = actual_root / actual_traces[trace_key]["traceRelativePath"]
        if not expected_trace_path.exists():
            diffs.append(f"audioTrace[{trace_key!r}]: missing expected trace file {expected_trace_path}")
            continue
        if not actual_trace_path.exists():
            diffs.append(f"audioTrace[{trace_key!r}]: missing actual trace file {actual_trace_path}")
            continue
        compare_json(
            load_json(expected_trace_path),
            load_json(actual_trace_path),
            f"audioTrace[{trace_key[0]}:{trace_key[1]}]",
            diffs,
        )

        expected_wav_path = expected_root / expected_traces[trace_key]["wavRelativePath"]
        actual_wav_path = actual_root / actual_traces[trace_key]["wavRelativePath"]
        if not expected_wav_path.exists():
            diffs.append(f"audioWav[{trace_key!r}]: missing expected wav file {expected_wav_path}")
            continue
        if not actual_wav_path.exists():
            diffs.append(f"audioWav[{trace_key!r}]: missing actual wav file {actual_wav_path}")
            continue

        expected_digest = file_digest(expected_wav_path)
        actual_digest = file_digest(actual_wav_path)
        if expected_digest != actual_digest:
            diffs.append(
                f"audioWav[{trace_key[0]}:{trace_key[1]}]: sha256 mismatch expected {expected_digest}, got {actual_digest}"
            )

    if diffs:
        print("Opening reference diff failed.")
        for diff in diffs[:200]:
            print(f"- {diff}")
        if len(diffs) > 200:
            print(f"... {len(diffs) - 200} additional diffs omitted")
        return 1

    print("Opening reference diff passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
