#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_PATTERN='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?'

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

show_help() {
  cat <<'EOF'
Usage: scripts/set-version.sh [VERSION] [--dry-run | --check]

Update the Meson version and tagged Flatpak source, or check release metadata.
VERSION must be MAJOR.MINOR.PATCH with an optional prerelease suffix.

  --dry-run  Validate and print planned updates without writing files.
  --check    Check Meson, Flatpak, and the newest AppStream release without
             writing files. Defaults to the Meson version. Requires xmllint.
  --help     Show this help message.

AppStream release notes and the Git tag must be updated manually.
EOF
}

read_version() {
  local filename="$1" pattern="$2" capture="$3"
  local line match
  local versions=()
  [[ -r "${filename}" ]] || fail "Cannot read ${filename}."
  while IFS= read -r line || [[ -n "${line}" ]]; do
    while [[ "${line}" =~ ${pattern} ]]; do
      match="${BASH_REMATCH[0]}"
      versions+=("${BASH_REMATCH[${capture}]}")
      line="${line#*"${match}"}"
    done
  done < "${filename}"
  [[ ${#versions[@]} -eq 1 ]] || fail "Expected one version field in \"${filename}\"."
  printf '%s\n' "${versions[0]}"
}

check_release() {
  local expected="$1" meson_version="$2" manifest_version="$3"
  local metainfo='data/com.vysp3r.ProtonPlus.metainfo.xml.in'
  local release='/component/releases/release[1]'
  local release_version release_date canonical_date notes
  local errors=()

  [[ "${meson_version}" == "${expected}" ]] ||
    errors+=("meson.build: expected version \"${expected}\", found \"${meson_version}\".")
  [[ "${manifest_version}" == "${expected}" ]] ||
    errors+=("com.vysp3r.ProtonPlus.yml: expected version \"${expected}\", found \"${manifest_version}\".")

  command -v xmllint >/dev/null 2>&1 || fail 'Missing required dependency: xmllint (libxml2 tools).'
  xmllint --nonet --noout "${metainfo}"
  if [[ "$(xmllint --nonet --xpath "count(${release})" "${metainfo}")" == 0 ]]; then
    errors+=("${metainfo##*/}: missing release entry.")
  else
    release_version="$(xmllint --nonet --xpath "string(${release}/@version)" "${metainfo}")"
    release_date="$(xmllint --nonet --xpath "string(${release}/@date)" "${metainfo}")"
    notes="$(xmllint --nonet --xpath "normalize-space(${release}/description[1])" "${metainfo}")"
    [[ "${release_version}" == "${expected}" ]] ||
      errors+=("${metainfo##*/}: newest release must be \"${expected}\", found \"${release_version}\".")
    if [[ ! "${release_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
       [[ "${release_date:0:4}" == 0000 ]] ||
       ! canonical_date="$(date -u -d "${release_date}" +%F 2>/dev/null)" ||
       [[ "${canonical_date}" != "${release_date}" ]]; then
      errors+=("${metainfo##*/}: newest release needs a valid YYYY-MM-DD date.")
    fi
    [[ -n "${notes}" ]] || errors+=("${metainfo##*/}: newest release needs release notes.")
  fi

  if (( ${#errors[@]} > 0 )); then
    printf 'error: %s\n' "${errors[@]}" >&2
    return 1
  fi
  printf 'Release metadata is consistent for version "%s".\n' "${expected}"
}

main() {
  local version='' mode='update' argument
  for argument in "$@"; do
    case "${argument}" in
      --help | -h) show_help; return 0 ;;
      --dry-run | --check)
        [[ "${mode}" == update || "${mode}" == "${argument}" ]] ||
          fail '--dry-run and --check are mutually exclusive.'
        mode="${argument}"
        ;;
      -*) fail "Unknown option: ${argument}." ;;
      *)
        [[ -z "${version}" ]] || fail 'Expected one VERSION argument.'
        [[ "${argument}" =~ ^${VERSION_PATTERN}$ ]] ||
          fail "Invalid version \"${argument}\". Expected MAJOR.MINOR.PATCH with an optional prerelease suffix."
        version="${argument}"
        ;;
    esac
  done
  [[ -n "${version}" || "${mode}" == --check ]] || fail 'VERSION is required unless --check is used.'

  cd "${PROJECT_ROOT}"
  local meson_version manifest_version
  meson_version="$(read_version meson.build "(^|[^[:alnum:]_])version: '(${VERSION_PATTERN})'" 2)"
  manifest_version="$(read_version com.vysp3r.ProtonPlus.yml "^[[:blank:]]*tag: v(${VERSION_PATTERN})[[:blank:]]*(#.*)?$" 1)"
  if [[ "${mode}" == --check ]]; then
    check_release "${version:-${meson_version}}" "${meson_version}" "${manifest_version}"
    return
  fi

  if [[ "${mode}" == --dry-run ]]; then
    printf 'Would patch "%s"...\n' meson.build com.vysp3r.ProtonPlus.yml
  else
    local temporary_dir
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf -- "${temporary_dir}"' EXIT
    sed -E "s/(^|[^[:alnum:]_])(version: ')${VERSION_PATTERN}'/\1\2${version}'/g" \
      meson.build > "${temporary_dir}/meson.build"
    sed -E "s/^([[:blank:]]*tag: v)${VERSION_PATTERN}/\1${version}/" \
      com.vysp3r.ProtonPlus.yml > "${temporary_dir}/com.vysp3r.ProtonPlus.yml"
    local filename
    for filename in meson.build com.vysp3r.ProtonPlus.yml; do
      printf 'Patching "%s"...\n' "${filename}"
      cat "${temporary_dir}/${filename}" > "${filename}"
    done
    rm -rf -- "${temporary_dir}"
    trap - EXIT
  fi

  printf 'Remember to perform the following actions manually:\n'
  printf -- '- Add version "%s" and its release notes to "data/com.vysp3r.ProtonPlus.metainfo.xml.in".\n' "${version}"
  printf -- '- Create and publish the Git tag "v%s".\n' "${version}"
}

main "$@"
