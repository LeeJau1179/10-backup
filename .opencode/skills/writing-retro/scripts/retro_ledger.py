#!/usr/bin/env python3
"""Manage the iterative writing-retro ledger and render AI 语录.md."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

SKILL_DIR = Path(__file__).resolve().parent.parent
DEFAULT_STATE_PATH = SKILL_DIR / "state.json"


def find_repo_root(start: Path) -> Path:
    """Walk upward from start to locate the repository root."""
    for parent in [start, *start.parents]:
        if (parent / ".git").exists() or (parent / "AGENTS.md").exists():
            return parent
    return start.parents[3]


REPO_ROOT = find_repo_root(SKILL_DIR)
SNAPSHOT_DIR = REPO_ROOT / ".agents" / "cache" / "writing-retro" / "snapshots"


def sanitize_scene_key(scene: str) -> str:
    """Convert a scene name or path into a safe single-segment filename stem."""
    name = Path(scene).stem if scene.endswith(".md") else scene.strip()
    sanitized = re.sub(r'[\\/:*?"<>|]+', "_", name).strip()
    if not sanitized:
        raise ValueError("Scene name cannot be empty")
    return sanitized


def load_state(state_path: Path) -> dict[str, Any]:
    """Load state JSON from disk."""
    with state_path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def save_state(state_path: Path, state: dict[str, Any]) -> None:
    """Persist state JSON with readable UTF-8 formatting."""
    with state_path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(state, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def rebalance_tiers(state: dict[str, Any]) -> tuple[list[str], list[str]]:
    """Promote items meeting the hit threshold and cap redlines at max_redlines."""
    cfg = state["config"]
    threshold = int(cfg.get("redline_threshold", 3))
    max_redlines = int(cfg.get("max_redlines", 8))

    promoted: list[str] = []
    demoted: list[str] = []

    for item in state["items"]:
        old_tier = item["tier"]
        hits = len(item.get("hit_scenes", []))
        if hits >= threshold:
            item["tier"] = "redline"
            if old_tier != "redline":
                promoted.append(item["id"])
        else:
            item["tier"] = "watch"

    redlines = [it for it in state["items"] if it["tier"] == "redline"]
    if len(redlines) > max_redlines:
        redlines.sort(
            key=lambda it: (
                -len(it.get("hit_scenes", [])),
                -int(it.get("last_order", 0)),
                it["id"],
            )
        )
        for overflow in redlines[max_redlines:]:
            overflow["tier"] = "watch"
            demoted.append(overflow["id"])
            if overflow["id"] in promoted:
                promoted.remove(overflow["id"])

    return promoted, demoted


def format_item_block(item: dict[str, Any], tier_label: str) -> list[str]:
    """Render one problem entry in clean Markdown without revision history or dates."""
    hits = len(item.get("hit_scenes", []))
    icon = "🔴" if tier_label == "红线" else "🟡"
    lines = [f"### {icon} [{tier_label}｜命中 {hits} 场] {item['title']}"]

    typical = (item.get("typical") or "").strip()
    if typical:
        lines.extend(["", f"**典型：** {typical}"])

    principles = [p.strip() for p in item.get("principles", []) if p and p.strip()]
    if principles:
        lines.extend(["", "**修改原则：**", ""])
        for idx, principle in enumerate(principles, start=1):
            lines.append(f"{idx}. {principle}")

    return lines


def render_notes_markdown(state: dict[str, Any]) -> str:
    """Render the clean AI 语录.md file from ledger state."""
    cfg = state["config"]
    threshold = int(cfg.get("redline_threshold", 3))
    max_redlines = int(cfg.get("max_redlines", 8))

    redlines = [it for it in state["items"] if it["tier"] == "redline"]
    watches = [it for it in state["items"] if it["tier"] != "redline"]

    sort_key = lambda it: (
        -len(it.get("hit_scenes", [])),
        -int(it.get("last_order", 0)) if len(it.get("hit_scenes", [])) > 0 else 0,
        it["id"],
    )
    redlines.sort(key=sort_key)
    watches.sort(key=sort_key)

    lines: list[str] = [
        "# 写作问题",
        "",
        f"> 写初稿与改稿前必读「高频红线」。累计命中达到 {threshold} 场的条目自动升入红线区（上限 {max_redlines} 条）。",
        "",
        f"## 🔴 高频红线（写初稿前必读・上限 {max_redlines} 条）",
    ]

    if not redlines:
        lines.extend(["", f"（暂无达到 {threshold} 场阈值的条目；随复盘累计自动晋升。）"])
    else:
        for item in redlines:
            lines.append("")
            lines.extend(format_item_block(item, "红线"))

    lines.extend(["", f"## 🟡 观察区（累计命中 ≥ {threshold} 场自动升入红线）"])

    if not watches:
        lines.extend(["", "（暂无观察项。）"])
    else:
        for item in watches:
            lines.append("")
            lines.extend(format_item_block(item, "观察"))

    return "\n".join(lines) + "\n"


def write_notes(repo_root: Path, state: dict[str, Any]) -> Path:
    """Write the rendered AI 语录.md to its configured path inside the repo."""
    notes_rel = state["config"]["notes_file"]
    notes_path = repo_root / notes_rel
    notes_path.parent.mkdir(parents=True, exist_ok=True)
    content = render_notes_markdown(state)
    with notes_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(content)
    return notes_path


def cmd_list(args: argparse.Namespace) -> int:
    state = load_state(Path(args.state))
    summary = [
        {
            "id": it["id"],
            "tier": it["tier"],
            "hits": len(it.get("hit_scenes", [])),
            "hit_scenes": it.get("hit_scenes", []),
            "title": it["title"],
            "principles": it.get("principles", []),
        }
        for it in state["items"]
    ]
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def cmd_snapshot(args: argparse.Namespace) -> int:
    scene_key = sanitize_scene_key(args.scene)
    snapshot_dir = Path(args.snapshot_dir)
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    target = snapshot_dir / f"{scene_key}.md"

    if args.file:
        text = Path(args.file).read_text(encoding="utf-8")
    elif args.stdin:
        text = sys.stdin.read()
    else:
        raise ValueError("Provide --file or --stdin when saving a snapshot")

    with target.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

    print(json.dumps({"snapshot_path": str(target), "scene_key": scene_key}, ensure_ascii=False))
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    state_path = Path(args.state)
    state = load_state(state_path)

    if args.json_file:
        payload = json.loads(Path(args.json_file).read_text(encoding="utf-8"))
    elif args.stdin:
        payload = json.loads(sys.stdin.read())
    else:
        raise ValueError("Provide --json-file or --stdin")

    scene = (payload.get("scene") or "").strip()
    if not scene:
        raise ValueError("Payload requires a non-empty 'scene' field")

    by_id = {it["id"]: it for it in state["items"]}
    updated_ids: list[str] = []
    added_ids: list[str] = []

    for hit in payload.get("hits", []):
        item_id = hit["id"]
        if item_id not in by_id:
            raise KeyError(f"Unknown item id: {item_id}")
        item = by_id[item_id]

        if scene not in item["hit_scenes"]:
            item["hit_scenes"].append(scene)
        order = int(state.get("next_order", 1))
        item["last_order"] = order
        state["next_order"] = order + 1

        if hit.get("title"):
            item["title"] = hit["title"].strip()
        if hit.get("typical") is not None:
            item["typical"] = hit["typical"].strip()
        if hit.get("principles") is not None:
            item["principles"] = [p.strip() for p in hit["principles"] if p and p.strip()]
        updated_ids.append(item_id)

    for new_item in payload.get("new_items", []):
        next_num = int(state.get("next_id", len(state["items"]) + 1))
        new_id = f"P{next_num:02d}"
        state["next_id"] = next_num + 1

        order = int(state.get("next_order", 1))
        state["next_order"] = order + 1

        entry = {
            "id": new_id,
            "tier": "watch",
            "title": new_item["title"].strip(),
            "typical": (new_item.get("typical") or "").strip(),
            "principles": [p.strip() for p in new_item.get("principles", []) if p and p.strip()],
            "hit_scenes": [scene],
            "last_order": order,
        }
        state["items"].append(entry)
        by_id[new_id] = entry
        added_ids.append(new_id)

    promoted, demoted = rebalance_tiers(state)
    save_state(state_path, state)
    notes_path = write_notes(Path(args.repo_root), state)

    snapshot_removed = False
    if payload.get("cleanup_snapshot", True):
        snap_path = Path(args.snapshot_dir) / f"{sanitize_scene_key(scene)}.md"
        if snap_path.exists():
            snap_path.unlink()
            snapshot_removed = True

    result = {
        "scene": scene,
        "updated_ids": updated_ids,
        "added_ids": added_ids,
        "promoted_to_redline": [
            {"id": pid, "hits": len(by_id[pid]["hit_scenes"]), "title": by_id[pid]["title"]}
            for pid in promoted
        ],
        "demoted_to_watch": [
            {"id": did, "hits": len(by_id[did]["hit_scenes"]), "title": by_id[did]["title"]}
            for did in demoted
        ],
        "active_redline_count": sum(1 for it in state["items"] if it["tier"] == "redline"),
        "notes_path": str(notes_path),
        "snapshot_removed": snapshot_removed,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    state_path = Path(args.state)
    state = load_state(state_path)
    promoted, demoted = rebalance_tiers(state)
    save_state(state_path, state)
    notes_path = write_notes(Path(args.repo_root), state)
    print(
        json.dumps(
            {
                "notes_path": str(notes_path),
                "promoted": promoted,
                "demoted": demoted,
                "item_count": len(state["items"]),
            },
            ensure_ascii=False,
        )
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Iterative writing-retro ledger tool.")
    parser.add_argument("--state", default=str(DEFAULT_STATE_PATH), help="Path to state.json")
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="Repository root path")
    parser.add_argument("--snapshot-dir", default=str(SNAPSHOT_DIR), help="Snapshot cache directory")

    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="List existing problem entries and hit counts")
    p_list.set_defaults(func=cmd_list)

    p_snap = sub.add_parser("snapshot", help="Save a draft baseline snapshot")
    p_snap.add_argument("--scene", required=True, help="Scene title or file name")
    p_snap.add_argument("--file", help="Source file path")
    p_snap.add_argument("--stdin", action="store_true", help="Read draft text from stdin")
    p_snap.set_defaults(func=cmd_snapshot)

    p_apply = sub.add_parser("apply", help="Apply confirmed retro updates and render notes")
    p_apply.add_argument("--json-file", help="Path to JSON update payload")
    p_apply.add_argument("--stdin", action="store_true", help="Read JSON payload from stdin")
    p_apply.set_defaults(func=cmd_apply)

    p_render = sub.add_parser("render", help="Rebalance tiers and render AI 语录.md")
    p_render.set_defaults(func=cmd_render)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
