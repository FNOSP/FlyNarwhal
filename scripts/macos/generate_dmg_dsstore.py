#!/usr/bin/env python3
"""Generate assets/macos/dmg/DS_Store for the macOS installer DMG.

create-dmg's AppleScript step (which normally lays out the Finder window)
needs a GUI session and is flaky on CI, so scripts/release/build_desktop.dart
runs create-dmg with --skip-jenkins and injects this pre-generated .DS_Store
into the volume instead. Finder applies icon view, window bounds, icon
positions and the background from it on every machine that opens the DMG.

The background alias is built to be volume-independent: it is matched by the
fixed volume name "FlyNarwhal" plus a volume-relative path (no disk UUID or
CNID), so the same .DS_Store works for every DMG the release pipeline builds.

Requires (regeneration only; the generated file is committed, CI needs no
Python):  pip install ds_store mac_alias

Usage: python3 scripts/macos/generate_dmg_dsstore.py
"""

import datetime
import os

from ds_store import DSStore
from mac_alias import Alias

VOLUME_NAME = b"FlyNarwhal"
# Where create-dmg places the background inside the volume (--background).
BACKGROUND_IN_VOLUME = b".background/dmg-background.png"
# Must match the create-dmg flags in scripts/release/build_desktop.dart.
WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H = 200, 120, 600, 400
ICON_SIZE = 96.0
TEXT_SIZE = 16.0
ICON_LOCATIONS = {
    "FlyNarwhal.app": (150, 210),
    "Applications": (450, 210),
    # Hidden volume files are only visible when Finder's "show hidden files"
    # is on; park them just past the window's right edge, mirroring
    # create-dmg's reposition-hidden-files step. NOTE: do NOT add an Iloc
    # entry for ".DS_Store" itself — a self-referential entry makes Finder
    # discard the whole layout and re-flow every icon.
    ".background": (700, 100),
    ".VolumeIcon.icns": (700, 220),
}

repo_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
background_src = os.path.join(repo_root, "assets", "macos", "dmg-background.png")
output = os.path.join(repo_root, "assets", "macos", "dmg", "DS_Store")

# Build the alias from the real background file (for valid stat metadata),
# then retarget it at the volume-relative location it will have inside the
# DMG, dropping the machine-specific CNID path.
alias = Alias.for_file(background_src)
alias.volume.name = VOLUME_NAME
alias.volume.creation_date = datetime.datetime(2024, 1, 1, tzinfo=datetime.timezone.utc)
alias.volume.posix_path = b"/Volumes/" + VOLUME_NAME
alias.target.folder_name = b".background"
alias.target.posix_path = b"/" + BACKGROUND_IN_VOLUME
alias.target.carbon_path = VOLUME_NAME + b":" + BACKGROUND_IN_VOLUME.replace(
    b"/", b":\0"
)
alias.target.cnid_path = []

icvp = {
    "viewOptionsVersion": 1,
    "backgroundType": 2,
    "backgroundImageAlias": alias.to_bytes(),
    # Fallback solid color if the background image cannot be resolved.
    "backgroundColorRed": 0.149,
    "backgroundColorGreen": 0.157,
    "backgroundColorBlue": 0.176,
    "gridOffsetX": 0.0,
    "gridOffsetY": 0.0,
    "gridSpacing": 100.0,
    "arrangeBy": "none",
    "showIconPreview": True,
    "showItemInfo": False,
    "labelOnBottom": True,
    "textSize": TEXT_SIZE,
    "iconSize": ICON_SIZE,
    "scrollPositionX": 0.0,
    "scrollPositionY": 0.0,
}

bwsp = {
    "ShowStatusBar": False,
    # WindowBounds is {{left, top}, {width, height}} (NOT corner coordinates).
    "WindowBounds": "{{%d, %d}, {%d, %d}}"
    % (WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H),
    "ContainerShowSidebar": False,
    "PreviewPaneVisibility": False,
    "SidebarWidth": 170,
    "ShowTabView": False,
    "ShowToolbar": False,
    "ShowPathbar": False,
    "ShowSidebar": False,
}

os.makedirs(os.path.dirname(output), exist_ok=True)
if os.path.exists(output):
    os.remove(output)
with DSStore.open(output, "w+") as d:
    d["."]["vSrn"] = ("long", 1)
    d["."]["bwsp"] = bwsp
    d["."]["icvp"] = icvp
    # icvl: default view = icon view ("icnv").
    d["."]["icvl"] = (b"type", b"icnv")
    for name, location in ICON_LOCATIONS.items():
        d[name]["Iloc"] = location

print("wrote", output)
