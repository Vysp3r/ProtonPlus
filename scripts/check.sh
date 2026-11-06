#!/usr/bin/env bash

set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: scripts/check.sh [AREA | GLIB_TEST_PATH ...]

Configure the build if needed, compile, run tests, and check diff whitespace.
Without arguments, run the full Meson suite. Paths such as /cli select focused
GLib tests and run from tests/ so relative fixtures resolve correctly.
Areas (include nested tests): downloads, providers, installation, steam,
launch-options, controller, cli. Explicit /paths keep GLib -p selection semantics.
Set BUILD_DIR to reuse a different build directory (default: build).
EOF
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    show_help
    exit 0
fi

test_paths=()
test_modes=()
for area in "$@"; do
    paths=()
    mode=-r
    case "${area}" in
        downloads) paths=(/web) ;;
        providers)
            paths=(
                /provider-definitions /provider-registry /providers
                /release-catalog /release-identity /assets
                /identity /install-layout /variant-compatibility
                /variant-selector /variant-settings
            )
            ;;
        installation)
            paths=(
                /installer-transaction /update-transaction /compatibility-process-guard
                /installed-tool-inventory /steamtinkerlaunch /tinkergame
            )
            ;;
        steam)
            paths=(
                /steam /steam-session /steam-configuration
                /steam-restart-manager /steam-restart-orchestrator /steam-restart-presentation
                /steam-game-launch /steam-compatibility-tool-discovery
            )
            ;;
        launch-options)
            paths=(
                /launch-options /launch-command /launch-command-parser
                /launch-command-composer /launch-command-editor-projection /launch-command-writer
                /launch-option-capabilities
            )
            ;;
        controller)
            paths=(
                /controller-control /controller-hints /controller-haptics
                /controller-input /controller-text-input /controller-navigation
                /controller-surfaces
            )
            ;;
        cli) paths=(/cli) ;;
        /*) paths=("${area}"); mode=-p ;;
        *)
            printf 'Unknown test area: %s; use --help or a GLib path starting with /.\n' "${area}" >&2
            exit 1
            ;;
    esac
    for test_path in "${paths[@]}"; do
        test_paths+=("${test_path}")
        test_modes+=("${mode}")
    done
done

for dependency in meson git; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
        printf 'Missing required dependency: %s\n' "${dependency}" >&2
        exit 1
    fi
done

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"
build_dir="${BUILD_DIR:-build}"
if [[ "${build_dir}" != /* ]]; then
    build_dir="${project_dir}/${build_dir}"
fi

if [[ ! -f "${build_dir}/meson-private/coredata.dat" ]]; then
    meson setup "${build_dir}"
fi
meson compile -C "${build_dir}"

if (( $# == 0 )); then
    meson test -C "${build_dir}" --no-rebuild --print-errorlogs
else
    # Keep archive and provider fixture paths relative to their owning directory.
    (
        cd "${project_dir}/tests"
        for index in "${!test_paths[@]}"; do
            test_path="${test_paths[index]}"
            mode="${test_modes[index]}"
            selection=$("${build_dir}/tests/protonplus-tests" --tap -l "${mode}" "${test_path}")
            # GLib exits successfully even when a mistyped path selects no tests.
            case "${selection}" in
                '1..0' | *$'\n1..0')
                    printf 'No GLib tests match: %s\n' "${test_path}" >&2
                    exit 1
                    ;;
            esac
            "${build_dir}/tests/protonplus-tests" "${mode}" "${test_path}"
        done
    )
fi

git diff --check
