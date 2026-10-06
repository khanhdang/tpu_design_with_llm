#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
model="${LLM_MODEL:-ollama/tpu-glm-4.7-flash:64k}"
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
# OpenCode CLI flags differ between releases. Use only advertised options.
run_help="$(opencode run --help 2>&1)"
run_flags=(--model "$model" --agent build)
if [[ "$run_help" == *"--standalone"* ]]; then
    run_flags+=(--standalone)
fi
if [[ "$run_help" == *"--auto"* ]]; then
    run_flags+=(--auto)
else
    echo "This OpenCode lacks --auto; install a version supporting unattended runs." >&2
    exit 1
fi
mkdir -p sim
log_dir="$(mktemp -d "$project_root/sim/build.XXXXXXXX")"
echo "Model: $model"
echo "Build logs: $log_dir"
workspace_prompt="Workspace: $project_root
This existing directory is the project root. Work directly here using its existing rtl/, tb/, and sim/ directories. All project file writes and build commands must stay inside this root. Do not create or switch to another project folder, rename the project, or derive a directory name from the model name."
for stage in mac pe array controller tpu regression; do
    target="$stage"
    [[ "$stage" != regression ]] || target=test
    prompt="$(cat "prompts/$stage.md")"
    passed=false
    for ((attempt=1; attempt<=attempts; attempt++)); do
        echo "=== $stage: attempt $attempt/$attempts ==="
        agent_log="$log_dir/$stage.$attempt.agent.log"
        verify_log="$log_dir/$stage.$attempt.verify.log"
        if ! bash scripts/run_opencode.sh run "${run_flags[@]}" "$workspace_prompt

$prompt" 2>&1 | tee "$agent_log"; then
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
