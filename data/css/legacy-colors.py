"""Generate GTK 4.14 stylesheets from the current stylesheets."""

import re
import sys
from pathlib import Path


# Libadwaita 1.5 has no named colors for these fixed accent values.
FIXED_ACCENTS = {
    "accent-blue": "#3584e4",
    "accent-green": "#3a944a",
    "accent-orange": "#ed5b00",
    "accent-purple": "#9141ac",
    "accent-red": "#e62d42",
}
PALETTE = re.compile(
    r"^\* \{\n((?:  --[\w-]+: [^;\n]+;\n|[ \t]*\n)+)\}\n\n",
    re.MULTILINE,
)


def convert(stylesheet):
    named_colors = set(re.findall(r"^@define-color ([\w-]+) ", stylesheet, re.MULTILINE))

    def convert_palette(block):
        declarations = re.findall(r"^  --([\w-]+): (.+);$", block[1], re.MULTILINE)
        fallback = []
        for name, value in declarations:
            name = name.replace("-", "_")
            if name not in named_colors:
                named_colors.add(name)
                fallback.append(f"@define-color {name} {value};\n")
        return "".join(fallback) + ("\n" if fallback else "")

    stylesheet = PALETTE.sub(convert_palette, stylesheet)
    return re.sub(
        r"var\(--([\w-]+)\)",
        lambda match: FIXED_ACCENTS.get(match[1], "@" + match[1].replace("-", "_")),
        stylesheet,
    )


for source in map(Path, sys.argv[2:]):
    css = convert(source.read_text(encoding="utf-8"))
    if re.search(r"\bvar\s*\(|^\s*--[\w-]+\s*:", css, re.MULTILINE):
        sys.exit(f"{source} has CSS custom properties without GTK 4.14 equivalents")
    output = Path(sys.argv[1]) / (source.stem + "-legacy.css")
    output.write_text(css, encoding="utf-8")
