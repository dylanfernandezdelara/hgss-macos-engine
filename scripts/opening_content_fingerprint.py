#!/usr/bin/env python3

import argparse
import hashlib
from pathlib import Path


REPO_INPUTS = [
    "scripts/ensure_python_tools.sh",
    "scripts/opening_asset_helper.py",
    "Sources/HGSSDataModel/HGSSOpeningBundle.swift",
    "Sources/HGSSExtractCLI",
    "Sources/HGSSOpeningIR",
]

PRET_INPUTS = [
    "src/intro_movie.c",
    "src/intro_movie_scene_1.c",
    "src/intro_movie_scene_2.c",
    "src/intro_movie_scene_3.c",
    "src/intro_movie_scene_4.c",
    "src/intro_movie_scene_5.c",
    "src/title_screen.c",
    "src/application/check_savedata.c",
    "src/application/main_menu/main_menu.c",
    "files/demo/opening/gs_opening",
    "files/demo/title/titledemo",
    "files/data/sound/gs_sound_data.sdat",
    "files/a/0/5/9",
    "files/graphic/font/font_00000000.bin",
    "files/graphic/font/font_00000007.bin",
    "charmap.txt",
]


def update_path(digest: "hashlib._Hash", label: str, root: Path, relative_path: str) -> None:
    target = root / relative_path
    digest.update(f"{label}:{relative_path}\n".encode("utf-8"))

    if not target.exists():
        digest.update(b"missing\n")
        return

    if target.is_dir():
        digest.update(b"dir\n")
        children = sorted(path for path in target.rglob("*") if path.is_file())
        for child in children:
            stat = child.stat()
            digest.update(
                f"{label}:{child.relative_to(root)}\0{stat.st_size}\0{stat.st_mtime_ns}\n".encode("utf-8")
            )
        return

    stat = target.stat()
    digest.update(f"{label}:{relative_path}\0{stat.st_size}\0{stat.st_mtime_ns}\n".encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute a lightweight fingerprint for extracted opening content inputs.")
    parser.add_argument("--repo-root", required=True, help="Repository root.")
    parser.add_argument("--pret-root", required=True, help="pret/pokeheartgold checkout root.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    pret_root = Path(args.pret_root).resolve()

    digest = hashlib.sha256()
    digest.update(b"hgss-opening-content-fingerprint-v1\n")

    for relative_path in REPO_INPUTS:
        update_path(digest, "repo", repo_root, relative_path)

    for relative_path in PRET_INPUTS:
        update_path(digest, "pret", pret_root, relative_path)

    print(digest.hexdigest())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
