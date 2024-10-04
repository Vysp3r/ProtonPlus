#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

SVG_DIR="data/logo"
EXPORT_DIR="data/logo/icons/hicolor"
ICON_SIZES=(512 256 128 64 48 32 16)

for svg_file in "${SVG_DIR}"/*.svg; do
    svg_name="$(basename "${svg_file}")"

    for size in "${ICON_SIZES[@]}"; do
        echo "${svg_name} @ ${size}"

        png_output_dir="${EXPORT_DIR}/${size}x${size}/apps"
        if [[ ! -d "${png_output_dir}" ]]; then
            mkdir -p "${png_output_dir}"
        fi

        png_file="${png_output_dir}/${svg_name%.*}.png"

        echo "-> ${png_file}"

        inkscape --export-type="png" \
            --export-filename="${png_file}" \
            --export-area-page \
            --export-width="${size}" \
            --export-height="${size}" \
            "${svg_file}"

        optipng -o7 "${png_file}"
    done
done
