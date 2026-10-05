#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
model="${LLM_MODEL:-ollama/tpu-devstral-small-2-24b:64k}"
attempts="${BUILD_ATTEMPTS:-3}"
if [[ ! "$attempts" =~ ^[1-9][0-9]*$ ]]; then
    echo "BUILD_ATTEMPTS must be a positive integer." >&2
    exit 1
fi
"${PYTHON:-python3}" scripts/check_env.py --opencode
if [[ "$model" == ollama/* ]]; then
    command -v ollama >/dev/null || { echo "Install Ollama first." >&2; exit 1; }
    ollama show "${model#ollama/}" >/dev/null || {
        echo "Start Ollama and run: ollama pull ${model#ollama/}" >&2
        exit 1
    }
fi
mkdir -p sim
log_dir="$(mktemp -d "$project_root/sim/build.XXXXXXXX")"
echo "Model: $model"
echo "Build logs: $log_dir"
for stage in mac pe array controller tpu regression; do
    target="$stage"
    [[ "$stage" != regression ]] || target=test
    prompt="$(cat "prompts/$stage.md")"
    passed=false
    for ((attempt=1; attempt<=attempts; attempt++)); do
        echo "=== $stage: attempt $attempt/$attempts ==="
        agent_log="$log_dir/$stage.$attempt.agent.log"
        verify_log="$log_dir/$stage.$attempt.verify.log"
        if ! bash scripts/run_opencode.sh run --standalone --model "$model" --agent build --auto "$prompt" 2>&1 | tee "$agent_log"; then
            echo "OpenCode failed; stopping. See $agent_log" >&2
            exit 1
        fi
        if make "$target" 2>&1 | tee "$verify_log"; then
            passed=true
            break
        fi
        prompt="Repair the $stage stage after failed verification. Read AGENTS.md, docs/architecture.md, Makefile, and the existing stage prompt prompts/$stage.md. Preserve working stages. Do not restart working files from scratch, change verification rules, weaken tests, or implement higher stages. Read the latest verification log at $verify_log and compiler/runtime logs under sim/. Fix the actual failure, run make $target, and report actual results."
    done
    if [[ "$passed" != true ]]; then
        echo "$stage failed after $attempts attempts; stopping. See $log_dir" >&2
        exit 1
    fi
done
echo "TPU build and full regression passed. Logs: $log_dir"
