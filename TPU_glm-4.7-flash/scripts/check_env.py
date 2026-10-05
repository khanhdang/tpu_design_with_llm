#!/usr/bin/env python3
"""Check simulation tools and, optionally, the OpenCode launcher configuration."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--opencode", action="store_true", help="also check optional OpenCode")
    args = parser.parse_args()
    errors = 0
    print(f"{'OK' if sys.version_info >= (3, 9) else 'MISSING'} Python >= 3.9")
    errors += sys.version_info < (3, 9)
    tools = ["make", "bash", os.environ.get("IVERILOG", "iverilog"), os.environ.get("VVP", "vvp")]
    if args.opencode:
        tools.append("opencode")
    for tool in tools:
        location = shutil.which(tool)
        print(f"{'OK' if location else 'MISSING'} {tool}: {location or 'not on PATH'}")
        errors += not bool(location)
    if args.opencode:
        try:
            config = json.loads((ROOT / "opencode.json").read_text())
            for stage in ("mac", "pe", "array", "controller", "tpu", "regression"):
                expected = "{file:prompts/" + stage + ".md}"
                if (config["command"][stage]["template"] != expected
                        or not (ROOT / "prompts" / (stage + ".md")).is_file()):
                    raise ValueError(f"missing or invalid {stage} command template")
            print("OK project OpenCode JSON and six command templates")
        except (OSError, ValueError, KeyError, TypeError) as exc:
            print(f"MISMATCH project config: {exc}")
            errors += 1
    print(f"\nENVIRONMENT: {'PASS' if errors == 0 else 'FAIL'} ({errors} issues)")
    return int(errors != 0)


if __name__ == "__main__":
    sys.exit(main())
