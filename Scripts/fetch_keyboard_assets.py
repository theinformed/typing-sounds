#!/usr/bin/env python3
"""fetch_keyboard_assets.py -- retrieve pinned MIT switch recordings for local builds.

Created by LT Sean Egan, PhD 2026-11-04
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

COMMIT = "ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4"
PACKS = {"nk-cream": "cream", "topre": "topre", "box-navy": "boxnavy",
         "tealios": "turquoise", "alps-blue": "bluealps"}
SAMPLES = {**{f"key{i + 1}": f"GENERIC_R{i}" for i in range(5)},
           "space": "SPACE", "backspace": "BACKSPACE", "return": "ENTER"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packs", nargs="+", choices=PACKS, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    manifest_path = root / "Resources/KeyboardSources.json"
    existing = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"files": []}
    records = {entry["path"]: entry for entry in existing["files"]}
    for slug in args.packs:
        for sample, original in SAMPLES.items():
            relative = f"Resources/SoundSources/kb-{slug}-{sample}.mp3"
            url = (f"https://raw.githubusercontent.com/tplai/kbsim/{COMMIT}/"
                   f"src/assets/audio/{PACKS[slug]}/press/{original}.mp3")
            with urllib.request.urlopen(url, timeout=30) as response:
                data = response.read(1_000_000)
            if len(data) < 128 or not (data[:3] == b"ID3" or data[0] == 0xFF):
                raise ValueError(f"Invalid MP3 response for {relative}")
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            records[relative] = {"path": relative, "url": url,
                                 "sha256": hashlib.sha256(data).hexdigest()}
        print(f"Fetched {slug}: eight switch recordings")
    manifest = {"repository": "https://github.com/tplai/kbsim", "commit": COMMIT,
                "license": "MIT", "copyright": "Thomas Lai",
                "licenseURL": f"https://github.com/tplai/kbsim/blob/{COMMIT}/LICENSE.md",
                "files": sorted(records.values(), key=lambda entry: entry["path"])}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Recorded {len(records)} sample hashes")


if __name__ == "__main__":
    main()
