#!/usr/bin/env python3
"""Refresh apps.json from the latest storytold releases.

python3 scripts/update.py [app ...]   update (all apps if none given)
python3 scripts/update.py --check     exit 1 if any app is behind, no writes
python3 scripts/update.py --self-test offline checks of the pure logic
"""

import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

REGISTRY = Path(__file__).resolve().parent.parent / "apps.json"
SYSTEMS = {"x86_64-linux": "x86_64", "aarch64-linux": "aarch64"}
APPS = {
    "cadcraft": ("CADCraft", "AutoCAD-style CAD and drafting"),
    "deckcraft": ("DeckCraft", "PowerPoint-style presentations and slide shows"),
    "designcraft": ("DesignCraft", "InDesign-style page layout and publishing"),
    "effectcraft": ("EffectCraft", "After Effects-style motion graphics and VFX"),
    "filmcraft": ("FilmCraft", "Premiere-style video editor"),
    "gridcraft": ("GridCraft", "Excel-style spreadsheet"),
    "lightcraft": ("LightCraft", "Lightroom-style photo library and raw processor"),
    "pdfcraft": ("PdfCraft", "Acrobat-style PDF reader, organizer and editor"),
    "photocraft": ("PhotoCraft", "Photoshop-style image editor"),
    "soundcraft": ("SoundCraft", "Pro Tools-style audio workstation"),
    "vectorcraft": ("VectorCraft", "Illustrator-style vector illustration"),
    "wordcraft": ("WordCraft", "Word-style word processor"),
}


def version_key(v):
    return tuple(int(x) for x in v.split("."))


def asset_name(app, version, arch):
    return f"{app}-{version}-linux-{arch}.tar.gz"


def latest_release(repo):
    req = urllib.request.Request(f"https://api.github.com/repos/{repo}/releases/latest")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def prefetch(url):
    out = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(out)["hash"]


def entry_for(app, release, old):
    version = release["tag_name"].removeprefix("v")
    assets = {a["name"]: a["browser_download_url"] for a in release["assets"]}
    title, description = APPS[app]
    sources = {}
    for system, arch in SYSTEMS.items():
        url = assets.get(asset_name(app, version, arch))
        if url:
            sources[system] = {"url": url, "hash": prefetch(url)}
    if not sources:
        raise RuntimeError(f"no linux tarball in {release['tag_name']}")
    return {
        "title": old.get("title", title),
        "description": old.get("description", description),
        "repo": f"storytold/{app}",
        "version": version,
        "tag": release["tag_name"],
        "desktopId": old.get("desktopId", f"ai.storyteller.{app}"),
        "sources": sources,
    }


def dump(registry):
    return json.dumps(registry, indent=2, sort_keys=True) + "\n"


def self_test():
    assert version_key("0.10.0") > version_key("0.9.9")
    assert asset_name("x", "1.2.3", "aarch64") == "x-1.2.3-linux-aarch64.tar.gz"
    assert dump({"b": 1, "a": 2}).startswith('{\n  "a"')
    assert set(SYSTEMS) == {"x86_64-linux", "aarch64-linux"}
    print("self-test ok")


def main(args):
    if "--self-test" in args:
        return self_test()
    check = "--check" in args
    names = [a for a in args if not a.startswith("--")] or sorted(APPS)
    registry = json.loads(REGISTRY.read_text()) if REGISTRY.exists() else {}
    failed, behind = [], []
    for app in names:
        old = registry.get(app, {})
        try:
            release = latest_release(f"storytold/{app}")
            new_version = release["tag_name"].removeprefix("v")
            if old and version_key(new_version) <= version_key(old["version"]):
                continue
            behind.append(app)
            if check:
                print(f"{app}: {old.get('version', 'missing')} -> {new_version}")
                continue
            registry[app] = entry_for(app, release, old)
            print(f"{app}: {old.get('version', 'new')} -> {new_version}")
        except Exception as e:  # noqa: BLE001 — keep the old entry, report, carry on
            print(f"{app}: FAILED: {e}", file=sys.stderr)
            failed.append(app)
    if not check:
        REGISTRY.write_text(dump(registry))
    return 1 if failed or (check and behind) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
