#!/usr/bin/env python3
"""Merge a partial mtool translation into an existing result by key, keeping a backup."""
from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import sys

from translate import TranslationError, atomic_write, digest, load_source, parse_json, read_json, render_output


def merge_translations(target_path: Path, patch_path: Path) -> tuple[int, Path | None]:
    """Merge flat string mappings from patch into target; return changed count and backup path or raise on invalid input."""
    target_path, patch_path = target_path.expanduser().resolve(), patch_path.expanduser().resolve()
    if target_path == patch_path:
        raise TranslationError("目标文件和局部译文不能是同一个文件。")
    source_text, entries, original_hash = load_source(target_path)
    target, patch = parse_json(source_text), read_json(patch_path)
    for name, value in (("目标文件", target), ("局部译文", patch)):
        if not isinstance(value, dict) or any(not isinstance(text, str) for text in value.values()):
            raise TranslationError(f"{name}必须是所有 value 均为字符串的 JSON 对象。")
    missing = set(patch) - set(target)
    if missing:
        raise TranslationError(f"局部译文中有 {len(missing)} 个 key 不存在于目标文件，未写入任何内容。")
    # Flat string objects have one source token per key in the same order.
    changes = {entry.id: patch[key] for key, entry in zip(target, entries, strict=True)
               if key in patch and target[key] != patch[key]}
    if not changes:
        return 0, None
    merged_text = render_output(source_text, entries, changes)
    original_bytes = target_path.read_bytes()
    if digest(original_bytes) != original_hash:
        raise TranslationError("目标文件在读取后发生变化，已停止合并。")
    backup_path = target_path.with_name(target_path.name + ".before-merge-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".bak")
    # Exclusive creation prevents replacing a previous backup; write the target only after backup succeeds.
    with backup_path.open("xb") as backup:
        backup.write(original_bytes)
    atomic_write(target_path, merged_text)
    return len(changes), backup_path


def main() -> int:
    """Parse target and patch paths, merge the translations, and return a Chinese status or error exit code."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="按 key 将局部译文合并到已有 mtool 终稿；写入前保留完整备份。")
    parser.add_argument("target", type=Path, help="需要更新的完整译文 JSON")
    parser.add_argument("patch", type=Path, help="包含待替换 key/value 的局部译文 JSON")
    args = parser.parse_args()
    try:
        changed, backup = merge_translations(args.target, args.patch)
    except (TranslationError, ValueError, OSError, TypeError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1
    print(f"已替换 {changed} 条译文：{args.target.expanduser().resolve()}")
    if backup:
        print(f"原文件备份：{backup}")
    else:
        print("译文已经一致，无需写入或新增备份。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())