#!/usr/bin/env python

from pathlib import Path
import re
import sys


SCRIPT_DIR = Path(__file__).parent.absolute()


def die(msg: str) -> None:
    print(msg)
    exit(1)


def file_rgx_replace(
    rgx: str, replacement: str, file: Path, max_count: int = 1, debug: bool = False
) -> None:
    print(f'Patching "{file.name}"...')
    text = file.read_text(encoding="utf-8")
    text = re.sub(rgx, replacement, text, max_count)
    if debug:
        print(text)
    else:
        file.write_text(text, encoding="utf-8")


new_version: str | None = None
if len(sys.argv) < 2:
    die("Usage: set-version.py <version number>\nExample: set-version.py 0.5.23")

new_version = sys.argv[1]
if re.search(r"^[0-9.\-]+$", new_version) is None:
    die(f'Invalid version specifier: "{new_version}"')

file_rgx_replace(  # Application version constant.
    r"(\bversion: ')[0-9.\-]+",
    rf"version: '{new_version}",
    SCRIPT_DIR / "../meson.build",
)

file_rgx_replace(  # Flathub manifest.
    r"(\burl: .+?\/ProtonPlus\.git[\s]*\btag:) v[0-9.\-]+",
    rf"\1 v{new_version}",
    SCRIPT_DIR / "../com.vysp3r.ProtonPlus.yml",
)

print(
    "Remember to perform the following actions manually:\n"
    f'- Add the version number ("{new_version}") and release notes to "data/com.vysp3r.ProtonPlus.metainfo.xml.in".\n'
    f'- Then create and publish a new Git tag: "v{new_version}"'
)
