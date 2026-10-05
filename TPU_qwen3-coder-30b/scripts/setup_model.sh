#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
ollama pull 'qwen3-coder:30b'
ollama create 'tpu-qwen3-coder-30b:64k' -f Modelfile
