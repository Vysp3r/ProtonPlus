#!/usr/bin/env python3

import sys
import json
import textwrap

def extract_descriptions(data, results):
    if isinstance(data, dict):
        for key, value in data.items():
            if key == "description" and isinstance(value, str) and value.strip():
                results.append(value.strip())
            else:
                extract_descriptions(value, results)
    elif isinstance(data, list):
        for item in data:
            extract_descriptions(item, results)

def main():
    if len(sys.argv) < 3:
        print("Usage: extract-translatables.py input1.json [input2.json ...] output.vala")
        sys.exit(1)

    input_files = sys.argv[1:-1]
    output_file = sys.argv[-1]

    results = []
    for input_file in input_files:
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        extract_descriptions(data, results)

    with open(output_file, 'w', encoding='utf-8') as f:
        lines = [f'N_("{json.dumps(desc)[1:-1]}")' for desc in results]
        f.write(textwrap.dedent(f"""\
            namespace ProtonPlus {{
            	static string[] translatables() {{
            		return {{
            			{',\n            			'.join(lines)}
            		}};
            	}}
            }}
        """))

if __name__ == "__main__":
    main()