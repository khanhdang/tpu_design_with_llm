#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
"${PYTHON:-python3}" scripts/check_env.py --opencode
# Keep caller-selected provider overlays; the project config loads from cwd.
# With no override, OpenCode uses its configured or interactively selected model.
if [[ -n "${LLM_MODEL:-}" ]]; then
    explicit_model=false
    for arg in "$@"; do
        case "$arg" in
            -m|--model|-m?*|--model=*) explicit_model=true ;;
        esac
    done
    if [[ "$explicit_model" == false ]]; then
        exec opencode --model "$LLM_MODEL" "$@"
    fi
fi
exec opencode "$@"
