#!/usr/bin/env python3

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
PRERELEASE_PATTERN = r"[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*"
VERSION_PATTERN = rf"\d+\.\d+\.\d+(?:-{PRERELEASE_PATTERN})?"


@dataclass(frozen=True)
class FileUpdate:
    path: Path
    pattern: str
    replacement: str


def validate_version(value: str) -> str:
    if re.fullmatch(VERSION_PATTERN, value) is None:
        raise ValueError(
            f'Invalid version "{value}". Expected MAJOR.MINOR.PATCH with an '
            "optional prerelease suffix."
        )
    return value


def apply_update(update: FileUpdate) -> str:
    text = update.path.read_text(encoding="utf-8")
    updated_text, replacement_count = re.subn(
        update.pattern,
        update.replacement,
        text,
        count=1,
    )
    if replacement_count != 1:
        raise ValueError(f'Expected one version field in "{update.path}".')
    return updated_text


def build_updates(version: str, project_root: Path = PROJECT_ROOT) -> list[FileUpdate]:
    return [
        FileUpdate(
            path=project_root / "meson.build",
            pattern=rf"(\bversion: '){VERSION_PATTERN}",
            replacement=rf"\g<1>{version}",
        ),
        FileUpdate(
            path=project_root / "com.vysp3r.ProtonPlus.yml",
            pattern=rf"(\btag: v){VERSION_PATTERN}",
            replacement=rf"\g<1>{version}",
        ),
    ]


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Update the ProtonPlus version.")
    parser.add_argument("version", type=validate_version)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and print changes without writing files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()
    updates = build_updates(args.version)

    try:
        prepared_updates = [(update, apply_update(update)) for update in updates]
    except (OSError, ValueError) as error:
        print(f"error: {error}")
        return 1

    for update, text in prepared_updates:
        action = "Would patch" if args.dry_run else "Patching"
        print(f'{action} "{update.path.relative_to(PROJECT_ROOT)}"...')
        if not args.dry_run:
            update.path.write_text(text, encoding="utf-8")

    print(
        "Remember to perform the following actions manually:\n"
        f'- Add version "{args.version}" and its release notes to '
        '"data/com.vysp3r.ProtonPlus.metainfo.xml.in".\n'
        f'- Create and publish the Git tag "v{args.version}".'
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
