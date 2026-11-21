#!/usr/bin/python3 -I
"""Select Proton using Proton-Autogen profiles, then hand off Steam's command."""

import os
from pathlib import Path
import re
import sys


RUNTIME_APP_ID = "4183110"


def normalize(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def runner_score(path, preferred):
    name = normalize(path.name)
    if "cachy" in name:
        family = 3
    elif "geproton" in name or "protonge" in name:
        family = 2
    elif "experimental" in name:
        family = 1
    else:
        family = 0
    version_name = path.name
    version_file = path / "version"
    if name.endswith("latest") and version_file.is_file():
        try:
            with version_file.open(encoding="utf-8") as stream:
                fields = stream.readline().split()
            if len(fields) > 1:
                version_name = fields[1]
        except (OSError, UnicodeError):
            pass
    version = tuple(int(number) for number in re.findall(r"\d+", version_name))
    return (name == preferred, family, version)


def supported_runner(path):
    proton = path / "proton"
    if not proton.is_file() or not os.access(proton, os.X_OK):
        return False
    manifest_path = path / "toolmanifest.vdf"
    if not manifest_path.is_file():
        return False
    try:
        manifest = manifest_path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError):
        return False
    # Only select Proton builds meant to run inside this Steam container.
    return re.search(r'(?m)^\s*"require_tool_appid"\s*"' + RUNTIME_APP_ID + r'"', manifest) is not None


def select_runner(roots, preferred):
    candidates = []
    for root in dict.fromkeys(Path(root) for root in roots):
        try:
            for path in sorted(root.iterdir()):
                if path.name.startswith((".", "__")) or not supported_runner(path):
                    continue
                candidates.append(path)
        except OSError:
            continue
    return max(candidates, key=lambda path: runner_score(path, preferred), default=None)


def log(message):
    print(f"Proton-Autogen: {message}", file=sys.stderr, flush=True)


def main(arguments):
    if len(arguments) < 2 or arguments[0] not in ("run", "waitforexitandrun"):
        return "expected a Steam launch verb and a Windows executable"
    if not os.environ.get("STEAM_COMPAT_DATA_PATH"):
        return "Steam did not provide a compatibility data path"

    root = Path(__file__).resolve().parent
    sys.path.insert(0, str(root))
    roots = [root.parent]
    client = os.environ.get("STEAM_COMPAT_CLIENT_INSTALL_PATH")
    if client:
        roots.extend((Path(client) / "compatibilitytools.d", Path(client) / "steamapps/common"))
    for library in os.environ.get("STEAM_COMPAT_LIBRARY_PATHS", "").split(os.pathsep):
        if library:
            roots.append(Path(library) / "steamapps/common")
    try:
        from proton_autogen.config import load_proton_paths

        roots.extend(path for path in load_proton_paths() if Path(path).is_absolute())
    except (ImportError, OSError) as error:
        log(f"could not load configured Proton paths: {error}")

    preference = ""
    try:
        from proton_autogen.loader import load_game_config

        profile = load_game_config(os.path.abspath(arguments[1])) or {}
        if isinstance(profile.get("proton"), str):
            preference = profile["proton"]
    except (ImportError, OSError, ValueError, AttributeError) as error:
        log(f"could not load the game profile: {error}")

    preferred_path = Path(os.path.expanduser(preference))
    preferred_name = normalize(preferred_path.name)
    explicit_path = preferred_path.is_absolute()
    if explicit_path and supported_runner(preferred_path):
        runner = preferred_path
    else:
        runner = select_runner(roots, preferred_name)
        if preference and (runner is None or explicit_path or normalize(runner.name) != preferred_name):
            log(f"preferred Proton build {preference!r} is unavailable for Steam Linux Runtime 4.0")
    if runner is None:
        return "install a Proton build that uses Steam Linux Runtime 4.0 (for example, Proton 11 or GE-Proton 11)"

    tool_paths = os.environ.get("STEAM_COMPAT_TOOL_PATHS", "").split(os.pathsep)
    os.environ["STEAM_COMPAT_TOOL_PATHS"] = os.pathsep.join(
        dict.fromkeys(path for path in [str(runner), *tool_paths] if path)
    )
    proton = runner / "proton"
    log(f"using {runner}")
    try:
        os.execv(proton, [str(proton), *arguments])
    except OSError as error:
        return f"could not start {proton}: {error.strerror}"


if __name__ == "__main__":
    error = main(sys.argv[1:])
    sys.exit(f"Proton-Autogen: {error}")
