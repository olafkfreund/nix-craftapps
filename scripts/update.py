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
SYSTEMS = ("x86_64-linux", "aarch64-linux", "aarch64-darwin")
APPS = {
    "cadcraft": ("CADCraft", "AutoCAD-style CAD and drafting"),
    "deckcraft": ("DeckCraft", "PowerPoint-style presentations and slide shows"),
    "designcraft": ("DesignCraft", "InDesign-style page layout and publishing"),
    "effectcraft": ("EffectCraft", "After Effects-style motion graphics and VFX"),
    "figcraft": ("FigCraft", "Figma-style interface design and prototyping"),
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


def asset_names(app, version, system):
    # The macOS DMG holds only the GUI; its CLI is a separate universal zip.
    if system.endswith("-darwin"):
        return [
            f"{app}-{version}-macos-universal.dmg",
            f"{app}-cli-{version}-macos-universal.zip",
        ]
    return [f"{app}-{version}-linux-{system.removesuffix('-linux')}.tar.gz"]


def systems_in(app, release):
    version = release["tag_name"].removeprefix("v")
    names = {a["name"] for a in release["assets"]}
    return {s for s in SYSTEMS if set(asset_names(app, version, s)) <= names}


def gained_systems(old, release, app):
    """Systems to add, or None when the release brings nothing new."""
    if not old:
        return sorted(systems_in(app, release))
    new, cur = (version_key(v) for v in (release["tag_name"].removeprefix("v"), old["version"]))
    gained = sorted(systems_in(app, release) - set(old["sources"]))
    return gained if new > cur or (new == cur and gained) else None


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
    # Same URL, same file: a release that only gains a system re-downloads nothing.
    known = {
        s["url"]: s["hash"]
        for src in old.get("sources", {}).values()
        for s in (src, src.get("cli", {}))
        if s
    }
    sources = {}
    for system in sorted(systems_in(app, release)):
        main, *cli = ({"url": assets[n]} for n in asset_names(app, version, system))
        for s in (main, *cli):
            s["hash"] = known.get(s["url"]) or prefetch(s["url"])
        sources[system] = main | ({"cli": cli[0]} if cli else {})
    missing = set(old.get("sources", SYSTEMS)) - set(sources)
    if missing or not sources:
        # Keep the old entry and retry next run: assets often upload one by one.
        raise RuntimeError(f"{release['tag_name']} lacks {sorted(missing) or 'release assets'}")
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
    assert asset_names("x", "1.2.3", "aarch64-linux") == ["x-1.2.3-linux-aarch64.tar.gz"]
    assert asset_names("x", "1.2.3", "aarch64-darwin") == [
        "x-1.2.3-macos-universal.dmg", "x-cli-1.2.3-macos-universal.zip"]
    assert dump({"b": 1, "a": 2}).startswith('{\n  "a"')
    assert set(SYSTEMS) == {"x86_64-linux", "aarch64-linux", "aarch64-darwin"}
    global prefetch
    prefetched = []
    prefetch = lambda url: prefetched.append(url) or "sha256-" + url
    asset = lambda n: {"name": n, "browser_download_url": n}
    rel = {"tag_name": "v1.0.0", "assets": [asset("x-1.0.0-linux-x86_64.tar.gz")]}
    APPS["x"] = ("X", "x")
    try:
        entry_for("x", rel, {"sources": {"x86_64-linux": {}, "aarch64-linux": {}}})
        raise AssertionError("accepted a release missing an arch")
    except RuntimeError:
        pass
    old = entry_for("x", rel, {"sources": {"x86_64-linux": {}}})
    assert old["version"] == "1.0.0"
    assert gained_systems(old, rel, "x") is None
    rel["assets"].append(asset("x-1.0.0-macos-universal.dmg"))
    assert gained_systems(old, rel, "x") is None, "added darwin without its CLI zip"
    rel["assets"].append(asset("x-cli-1.0.0-macos-universal.zip"))
    assert gained_systems(old, rel, "x") == ["aarch64-darwin"]
    prefetched.clear()
    new = entry_for("x", rel, old)
    assert prefetched == ["x-1.0.0-macos-universal.dmg", "x-cli-1.0.0-macos-universal.zip"]
    assert new["sources"]["aarch64-darwin"]["cli"]["hash"] == "sha256-x-cli-1.0.0-macos-universal.zip"
    assert gained_systems(new, {**rel, "tag_name": "v0.9.0"}, "x") is None
    assert gained_systems(new, {**rel, "tag_name": "v1.0.1"}, "x") == []
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
            gained = gained_systems(old, release, app)
            if gained is None:
                continue
            behind.append(app)
            change = f"{old.get('version', 'new')} -> {release['tag_name'].removeprefix('v')}"
            change += f" (+{', '.join(gained)})" if old and gained else ""
            if not check:
                registry[app] = entry_for(app, release, old)
            print(f"{app}: {change}")
        except Exception as e:  # noqa: BLE001 — keep the old entry, report, carry on
            print(f"{app}: FAILED: {e}", file=sys.stderr)
            failed.append(app)
    if not check:
        REGISTRY.write_text(dump(registry))
    return 1 if failed or (check and behind) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
