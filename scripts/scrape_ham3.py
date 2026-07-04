#!/usr/bin/env python3
"""Scrape アマチュア無線技士3級問題集 from soft.taprix.org and generate ham3.json + images.

Source: https://soft.taprix.org/web/mn2/ham3/
License: PG-MANA/MN2 (see site footer)
"""

from __future__ import annotations

import json
import urllib.request
from pathlib import Path

BASE_URL = "https://soft.taprix.org/web/mn2/ham3"
JSON_BASE = f"{BASE_URL}/config/json"
IMG_BASE = f"{BASE_URL}/config/img"

ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "Sources/ANKI-HUB-iOS/Resources/ham3.json"
OUT_IMG_DIR = ROOT / "Sources/ANKI-HUB-iOS/Resources/ham3_images"


def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=30) as resp:
        return json.load(resp)


def download_file(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        return
    with urllib.request.urlopen(url, timeout=30) as resp:
        dest.write_bytes(resp.read())


def main() -> None:
    config = fetch_json(f"{JSON_BASE}/config.json")
    items: list[dict] = []
    downloaded_images: set[str] = set()

    for cat in config["list"]:
        prefix = cat["prefix"]
        name = cat["name"]
        for exam_no in range(1, cat["num"] + 1):
            url = f"{JSON_BASE}/{prefix}/{exam_no}.json"
            questions = fetch_json(url)
            category = f"{name} 第{exam_no}回"

            for q_idx, q in enumerate(questions, start=1):
                select = q.get("select") or []
                if len(select) < 2:
                    print(f"⚠️ skip {category} Q{q_idx}: insufficient choices")
                    continue

                item_id = f"{prefix}-{exam_no}-{q_idx}"
                entry: dict = {
                    "id": item_id,
                    "category": category,
                    "text": q.get("text", "").strip(),
                    "select": select,
                    "imagePrefix": prefix,
                }

                imgs = q.get("img") or []
                if imgs:
                    entry["images"] = imgs
                    for img_name in imgs:
                        key = f"{prefix}/{img_name}"
                        if key not in downloaded_images:
                            img_url = f"{IMG_BASE}/{prefix}/{img_name}"
                            dest = OUT_IMG_DIR / prefix / img_name
                            download_file(img_url, dest)
                            downloaded_images.add(key)

                items.append(entry)

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"✅ Wrote {len(items)} questions to {OUT_JSON}")
    print(f"✅ Downloaded {len(downloaded_images)} images to {OUT_IMG_DIR}")


if __name__ == "__main__":
    main()
