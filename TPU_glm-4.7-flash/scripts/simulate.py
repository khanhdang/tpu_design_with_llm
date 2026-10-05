#!/usr/bin/env python3
"""Run ordered, self-checking Icarus simulations from any working directory."""
import argparse
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
SIM = ROOT / "sim"
# No wildcards: each stage has an explicit dependency list and selected TB top.
STAGES = {
    "mac": ("mac", ["mac"]),
    "pe": ("pe", ["mac", "pe"]),
    "array": ("systolic_array", ["mac", "pe", "systolic_array"]),
    "controller": ("controller", ["controller"]),
    "tpu": ("tpu_top", ["mac", "pe", "systolic_array", "controller", "tpu_top"]),
}


def source(directory, stem):
    candidates = [ROOT / directory / (stem + suffix) for suffix in (".sv", ".v")]
    found = [p for p in candidates if p.is_file()]
    if len(found) != 1:
        raise RuntimeError(f"Expected exactly one of {candidates[0].relative_to(ROOT)} "
                           f"or {candidates[1].relative_to(ROOT)}; found {len(found)}. "
                           "Implement this stage before running it.")
    return found[0]


def execute(command, log, timeout):
    print("+ " + shlex.join(str(arg) for arg in command), flush=True)
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        output = result.stdout.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"").decode("utf-8", errors="replace")
        output += f"\nFAIL: process timed out after {timeout} seconds\n"
        log.write_text(output)
        print(output, end="", flush=True)
        raise RuntimeError(f"Timeout; see {log.relative_to(ROOT)}") from exc
    log.write_text(output)
    print(output, end="", flush=True)
    if result.returncode:
        raise RuntimeError(f"Command exited {result.returncode}; see {log.relative_to(ROOT)}")
    return output


def run_stage(stage, timeout):
    module, dependencies = STAGES[stage]
    artifact = SIM / (module + "_sim.vvp")
    # Remove stale evidence before checking source files or compiling.
    for path in (artifact, SIM / (module + "_compile.log"), SIM / (module + "_run.log"),
                 SIM / (module + "_tb.vcd")):
        path.unlink(missing_ok=True)
    sources = [source("rtl", name) for name in dependencies]
    testbench = source("tb", module + "_tb")
    compiler = os.environ.get("IVERILOG", "iverilog")
    runtime = os.environ.get("VVP", "vvp")
    for tool in (compiler, runtime):
        if not shutil.which(tool):
            raise RuntimeError(f"Missing executable: {tool}")
    print(f"\n=== {module}: compile and simulate ===", flush=True)
    execute([compiler, "-g2012", "-Wall", "-s", module + "_tb", "-o", str(artifact),
             *map(str, sources), str(testbench)], SIM / (module + "_compile.log"), 60)
    output = execute([runtime, str(artifact)], SIM / (module + "_run.log"), timeout)
    summary = re.findall(r"^\s*" + module.upper() + r" TEST RESULT: (PASS|FAIL)\s*$",
                         output, flags=re.MULTILINE)
    tests = re.findall(r"^\s*Tests:\s*(\d+)\s*$", output, flags=re.MULTILINE)
    errors = re.findall(r"^\s*Errors:\s*(\d+)\s*$", output, flags=re.MULTILINE)
    if (summary != ["PASS"] or len(tests) != 1 or int(tests[0]) == 0
            or errors != ["0"] or re.search(r"\b(?:FAIL|FATAL|ERROR)\b", output, re.IGNORECASE)):
        raise RuntimeError(f"Invalid or failing self-check summary; see sim/{module}_run.log. "
                           f"Require '{module.upper()} TEST RESULT: PASS', Tests: >0, Errors: 0.")
    print(f"Verified {module}: {tests[0]} checks, 0 errors", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", nargs="?", choices=[*STAGES, "all"], default="all")
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()
    if args.clean:
        for module, _ in STAGES.values():
            for suffix in ("_sim.vvp", "_compile.log", "_run.log", "_tb.vcd"):
                (SIM / (module + suffix)).unlink(missing_ok=True)
        print("Removed named simulation artifacts.")
        return 0
    SIM.mkdir(exist_ok=True)
    try:
        timeout = float(os.environ.get("SIM_TIMEOUT", "30"))
        if not 0 < timeout < float("inf"):
            raise ValueError("SIM_TIMEOUT must be finite and positive")
        stages = list(STAGES)
        selected = stages if args.stage == "all" else stages[:stages.index(args.stage) + 1]
        for stage in selected:
            run_stage(stage, timeout)
    except (RuntimeError, OSError, ValueError) as exc:
        print(f"\nSIMULATION RESULT: FAIL\n{exc}", file=sys.stderr)
        return 1
    print(f"\nSIMULATION RESULT: PASS ({len(selected)} stages)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
