#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
ollama pull 'qwen3.5:9b'
ollama create 'tpu-qwen3.5-9b:64k' -f Modelfile
