import argparse
import json
import os
import pathlib
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional


def normalize_word(raw: Optional[str]) -> str:
    if raw is None:
        return ""
    return str(raw).strip().replace(" ", "").replace("\u3000", "")


def load_json(path: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError(f"Expected list json: {path}")
    return [x for x in data if isinstance(x, dict)]


def resolve_under_repo_root(raw_path: str) -> str:
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    candidate = pathlib.Path(raw_path)
    if not candidate.is_absolute():
        candidate = (repo_root / candidate)
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError:
        raise SystemExit(f"Path must be under repo root: {raw_path}")
    return str(resolved)


def resource_path(key: str) -> str:
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    resources = repo_root / "Sources" / "ANKI-HUB-iOS" / "Resources"
    mapping = {
        "kobun": resources / "kobun.json",
        "kobun_pdf": resources / "kobun_pdf.json",
    }
    if key not in mapping:
        raise SystemExit(f"Unknown key: {key}")
    return str(mapping[key])


@dataclass(frozen=True)
class DiffReport:
    base_count: int
    other_count: int
    base_only: List[str]
    other_only: List[str]
    common: int
    base_missing_hint_but_other_has: List[str]
    meaning_diff: List[str]


def index_by_word(items: Iterable[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for it in items:
        key = normalize_word(it.get("word"))
        if not key:
            continue
        if key not in out:
            out[key] = it
    return out


def compare(base: List[Dict[str, Any]], other: List[Dict[str, Any]]) -> DiffReport:
    base_by = index_by_word(base)
    other_by = index_by_word(other)

    base_keys = set(base_by.keys())
    other_keys = set(other_by.keys())

    base_only = sorted(base_keys - other_keys)
    other_only = sorted(other_keys - base_keys)
    common_keys = base_keys & other_keys

    base_missing_hint: List[str] = []
    meaning_diff: List[str] = []

    for k in sorted(common_keys):
        b = base_by[k]
        o = other_by[k]

        b_hint = b.get("hint")
        o_hint = o.get("hint")
        if (not b_hint or str(b_hint).strip() == "") and (o_hint and str(o_hint).strip() != ""):
            base_missing_hint.append(k)

        b_mean = str(b.get("meaning") or "").strip()
        o_mean = str(o.get("meaning") or "").strip()
        if b_mean and o_mean and b_mean != o_mean:
            meaning_diff.append(k)

    return DiffReport(
        base_count=len(base_by),
        other_count=len(other_by),
        base_only=base_only,
        other_only=other_only,
        common=len(common_keys),
        base_missing_hint_but_other_has=base_missing_hint,
        meaning_diff=meaning_diff,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, choices=["kobun", "kobun_pdf"])
    parser.add_argument("--other", required=True, choices=["kobun", "kobun_pdf"])
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()

    base_path = resource_path(args.base)
    other_path = resource_path(args.other)

    if not os.path.exists(base_path):
        raise SystemExit(f"Not found: {base_path}")
    if not os.path.exists(other_path):
        raise SystemExit(f"Not found: {other_path}")

    base = load_json(base_path)
    other = load_json(other_path)
    r = compare(base, other)

    def head(xs: List[str]) -> List[str]:
        return xs[: max(0, args.limit)]

    print("=== Kobun Diff Report ===")
    print(f"base:  {base_path} (unique words={r.base_count})")
    print(f"other: {other_path} (unique words={r.other_count})")
    print(f"common: {r.common}")
    print(f"base_only: {len(r.base_only)}")
    print(f"other_only: {len(r.other_only)}")
    print(f"base_missing_hint_but_other_has: {len(r.base_missing_hint_but_other_has)}")
    print(f"meaning_diff (non-empty mismatch): {len(r.meaning_diff)}")

    if r.base_only:
        print("\n-- base_only (head) --")
        print("\n".join(head(r.base_only)))

    if r.other_only:
        print("\n-- other_only (head) --")
        print("\n".join(head(r.other_only)))

    if r.base_missing_hint_but_other_has:
        print("\n-- base_missing_hint_but_other_has (head) --")
        print("\n".join(head(r.base_missing_hint_but_other_has)))

    if r.meaning_diff:
        print("\n-- meaning_diff (head) --")
        print("\n".join(head(r.meaning_diff)))


if __name__ == "__main__":
    main()
